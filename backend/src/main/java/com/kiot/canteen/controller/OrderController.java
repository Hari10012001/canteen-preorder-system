package com.kiot.canteen.controller;

import com.kiot.canteen.config.CurrentUser;
import com.kiot.canteen.dto.CreateOrderRequest;
import com.kiot.canteen.dto.OrderDto;
import com.kiot.canteen.service.OrderService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Duration;
import java.util.List;

@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @PostMapping
    public OrderDto create(HttpServletRequest request, @Valid @RequestBody CreateOrderRequest body) {
        return orderService.create(CurrentUser.id(request), body);
    }

    @GetMapping("/my")
    public List<OrderDto> myOrders(HttpServletRequest request) {
        return orderService.myOrders(CurrentUser.id(request));
    }

    @GetMapping("/{id}")
    public OrderDto get(HttpServletRequest request, @PathVariable Long id) {
        return orderService.get(id, CurrentUser.id(request));
    }

    /** Real scannable QR code rendered server-side as a PNG. */
    @GetMapping(value = "/{id}/qr", produces = MediaType.IMAGE_PNG_VALUE)
    public ResponseEntity<byte[]> qr(HttpServletRequest request, @PathVariable Long id) {
        byte[] png = orderService.qrPng(id, CurrentUser.id(request));
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_PNG)
                .cacheControl(CacheControl.maxAge(Duration.ofSeconds(30)))
                .body(png);
    }
}
