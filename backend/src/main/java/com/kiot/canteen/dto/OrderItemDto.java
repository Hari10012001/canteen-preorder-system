package com.kiot.canteen.dto;

import java.math.BigDecimal;

public record OrderItemDto(
        Long foodItemId,
        String name,
        String imageUrl,
        BigDecimal unitPrice,
        int quantity,
        BigDecimal lineTotal
) {
}
