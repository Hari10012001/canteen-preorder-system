package com.kiot.canteen.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

public record OrderDto(
        Long id,
        String orderCode,
        UserDto user,
        List<OrderItemDto> items,
        BigDecimal totalAmount,
        int itemCount,
        LocalDate pickupDate,
        String pickupSlot,
        String paymentMethod,
        String paymentStatus,
        String orderStatus,
        LocalDateTime createdAt
) {
}
