package com.kiot.canteen.controller;

import com.kiot.canteen.dto.FoodDto;
import com.kiot.canteen.dto.PickupConfigDto;
import com.kiot.canteen.service.FoodService;
import com.kiot.canteen.service.OrderService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/foods")
public class FoodController {

    private final FoodService foodService;
    private final OrderService orderService;

    public FoodController(FoodService foodService, OrderService orderService) {
        this.foodService = foodService;
        this.orderService = orderService;
    }

    /** GET /api/foods?search=&category= */
    @GetMapping
    public List<FoodDto> list(@RequestParam(required = false) String search,
                              @RequestParam(required = false) String category) {
        return foodService.find(search, category);
    }

    /** Category filter chips, including the "All" reset option. */
    @GetMapping("/categories")
    public List<String> categories() {
        return foodService.categories();
    }

    @GetMapping("/pickup-config")
    public PickupConfigDto pickupConfig() {
        return new PickupConfigDto(orderService.slots(), orderService.maxAdvanceDays());
    }

    @GetMapping("/{id}")
    public FoodDto get(@PathVariable Long id) {
        return foodService.get(id);
    }
}
