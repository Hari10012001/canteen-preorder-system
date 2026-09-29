package com.kiot.canteen.service;

import com.kiot.canteen.dto.CreateOrderRequest;
import com.kiot.canteen.dto.OrderDto;
import com.kiot.canteen.dto.OrderItemDto;
import com.kiot.canteen.dto.UserDto;
import com.kiot.canteen.entity.*;
import com.kiot.canteen.repository.FoodItemRepository;
import com.kiot.canteen.repository.OrderRepository;
import com.kiot.canteen.repository.PaymentRepository;
import com.kiot.canteen.repository.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class OrderService {

    private static final Object CODE_LOCK = new Object();
    private static final List<String> ALLOWED_SLOTS = List.of(
            "12:00 - 12:15", "12:15 - 12:30", "12:30 - 12:45",
            "01:00 - 01:15", "01:15 - 01:30");

    private final OrderRepository orders;
    private final UserRepository users;
    private final FoodItemRepository foods;
    private final PaymentRepository payments;
    private final QrService qrService;

    @Value("${kiot.canteen.max-advance-days:7}")
    private int maxAdvanceDays;

    public OrderService(OrderRepository orders, UserRepository users, FoodItemRepository foods,
                        PaymentRepository payments, QrService qrService) {
        this.orders = orders;
        this.users = users;
        this.foods = foods;
        this.payments = payments;
        this.qrService = qrService;
    }

    /**
     * Loads the order and renders the QR inside one transaction so the lazily
     * loaded item collection is still attached to a session.
     */
    @Transactional(readOnly = true)
    public byte[] qrPng(Long orderId, Long userId) {
        return qrService.toPng(requireOwned(orderId, userId));
    }

    @Transactional
    public OrderDto create(Long userId, CreateOrderRequest req) {
        User user = users.findById(userId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        LocalDate today = LocalDate.now();
        if (req.pickupDate().isBefore(today)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Pickup date cannot be in the past");
        }
        if (req.pickupDate().isAfter(today.plusDays(maxAdvanceDays))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Pickup date must be within the next " + maxAdvanceDays + " days");
        }
        if (!ALLOWED_SLOTS.contains(req.pickupSlot())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid pickup slot");
        }

        PaymentMethod method;
        try {
            method = PaymentMethod.valueOf(req.paymentMethod().trim().toUpperCase());
        } catch (IllegalArgumentException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid payment method");
        }

        Map<Long, FoodItem> catalog = foods.findAllById(req.items().stream()
                        .map(CreateOrderRequest.Item::foodItemId)
                        .collect(Collectors.toSet()))
                .stream()
                .collect(Collectors.toMap(FoodItem::getId, Function.identity()));

        Order order = new Order();
        order.setUser(user);
        order.setOrderCode(nextOrderCode());
        order.setPickupDate(req.pickupDate());
        order.setPickupSlot(req.pickupSlot());
        order.setPaymentMethod(method);
        // UPI / Card are treated as paid instantly in this demo. Cash stays pending.
        order.setPaymentStatus(method == PaymentMethod.CASH ? PaymentStatus.PENDING : PaymentStatus.PAID);
        order.setOrderStatus(OrderStatus.CONFIRMED);

        BigDecimal total = BigDecimal.ZERO;
        for (CreateOrderRequest.Item line : req.items()) {
            FoodItem food = catalog.get(line.foodItemId());
            if (food == null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Food item not found: " + line.foodItemId());
            }
            if (!food.isAvailable()) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, food.getName() + " is currently unavailable");
            }
            BigDecimal lineTotal = food.getPrice().multiply(BigDecimal.valueOf(line.quantity()));
            total = total.add(lineTotal);

            OrderItem oi = new OrderItem();
            oi.setFoodItem(food);
            oi.setItemName(food.getName());
            oi.setUnitPrice(food.getPrice());
            oi.setQuantity(line.quantity());
            oi.setLineTotal(lineTotal);
            order.addItem(oi);
        }
        order.setTotalAmount(total);

        Order saved = orders.save(order);

        Payment payment = new Payment();
        payment.setOrder(saved);
        payment.setMethod(method);
        payment.setStatus(order.getPaymentStatus());
        payment.setAmount(total);
        payment.setReference(method == PaymentMethod.CASH
                ? "PAY_AT_COUNTER"
                : "DEMO-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase());
        payments.save(payment);

        return toDto(saved);
    }

    @Transactional(readOnly = true)
    public List<OrderDto> myOrders(Long userId) {
        return orders.findByUserIdOrderByCreatedAtDesc(userId).stream().map(this::toDto).toList();
    }

    @Transactional(readOnly = true)
    public Order requireOwned(Long orderId, Long userId) {
        Order order = orders.findById(orderId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));
        if (!order.getUser().getId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You cannot view this order");
        }
        return order;
    }

    @Transactional(readOnly = true)
    public OrderDto get(Long orderId, Long userId) {
        return toDto(requireOwned(orderId, userId));
    }

    @Transactional(readOnly = true)
    public OrderDto getByCode(String code, Long userId) {
        Order order = orders.findByOrderCode(code)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found"));
        if (!order.getUser().getId().equals(userId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "You cannot view this order");
        }
        return toDto(order);
    }

    public List<String> slots() {
        return ALLOWED_SLOTS;
    }

    public int maxAdvanceDays() {
        return maxAdvanceDays;
    }

    /** KIOT-CAN-2026-00001 - sequential per calendar year. */
    private String nextOrderCode() {
        synchronized (CODE_LOCK) {
            int year = LocalDate.now().getYear();
            String prefix = "KIOT-CAN-" + year + "-";
            for (int seq = 1; seq <= 99999; seq++) {
                String code = prefix + String.format("%05d", seq);
                if (!orders.existsByOrderCode(code)) {
                    return code;
                }
            }
        }
        throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Unable to allocate order number");
    }

    public OrderDto toDto(Order o) {
        List<OrderItemDto> items = o.getItems().stream()
                .map(i -> new OrderItemDto(
                        i.getFoodItem() != null ? i.getFoodItem().getId() : null,
                        i.getItemName(),
                        i.getFoodItem() != null ? i.getFoodItem().getImageUrl() : null,
                        i.getUnitPrice(),
                        i.getQuantity(),
                        i.getLineTotal()))
                .toList();

        int itemCount = items.stream().mapToInt(OrderItemDto::quantity).sum();
        UserDto user = new UserDto(o.getUser().getId(), o.getUser().getName(),
                o.getUser().getEmail(), o.getUser().getStudentId(), o.getUser().getRole());

        return new OrderDto(
                o.getId(), o.getOrderCode(), user, items, o.getTotalAmount(), itemCount,
                o.getPickupDate(), o.getPickupSlot(),
                o.getPaymentMethod().name(), o.getPaymentStatus().name(),
                o.getOrderStatus().name(), o.getCreatedAt());
    }

    public static LocalDateTime now() {
        return LocalDateTime.now();
    }
}
