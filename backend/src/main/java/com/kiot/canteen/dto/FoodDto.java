package com.kiot.canteen.dto;

import com.kiot.canteen.entity.FoodItem;

import java.math.BigDecimal;

public record FoodDto(
        Long id,
        String name,
        String description,
        BigDecimal price,
        String category,
        String imageUrl,
        boolean available,
        int prepTimeMins,
        boolean veg
) {
    public static FoodDto from(FoodItem f) {
        return new FoodDto(
                f.getId(), f.getName(), f.getDescription(), f.getPrice(), f.getCategory(),
                f.getImageUrl(), f.isAvailable(), f.getPrepTimeMins(), f.isVeg());
    }
}
