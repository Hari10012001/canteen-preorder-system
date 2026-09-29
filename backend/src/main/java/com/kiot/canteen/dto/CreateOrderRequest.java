package com.kiot.canteen.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.time.LocalDate;
import java.util.List;

public record CreateOrderRequest(

        @NotEmpty(message = "Cart is empty")
        @Valid
        List<Item> items,

        @NotNull(message = "Pickup date is required")
        LocalDate pickupDate,

        @NotBlank(message = "Pickup time slot is required")
        String pickupSlot,

        @NotBlank(message = "Payment method is required")
        String paymentMethod
) {

    public record Item(
            @NotNull(message = "Food item id is required") Long foodItemId,
            @Min(value = 1, message = "Quantity must be at least 1") int quantity
    ) {
    }
}
