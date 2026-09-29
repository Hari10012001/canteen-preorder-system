package com.kiot.canteen.service;

import com.kiot.canteen.dto.FoodDto;
import com.kiot.canteen.entity.FoodItem;
import com.kiot.canteen.repository.FoodItemRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@Service
public class FoodService {

    /** Fixed display order for the category filter chips. "All" is the reset sentinel. */
    private static final List<String> CATEGORY_ORDER = List.of(
            "All", "Rice", "Biryani", "Noodles", "Parotta", "Dosa", "Idli", "Tiffin");

    private final FoodItemRepository foods;

    public FoodService(FoodItemRepository foods) {
        this.foods = foods;
    }

    public List<FoodDto> find(String query, String category) {
        String q = query == null ? "" : query.trim();
        String cat = category == null ? "" : category.trim();

        List<FoodItem> result;
        boolean hasQuery = !q.isEmpty();
        boolean hasCategory = !cat.isEmpty() && !"All".equalsIgnoreCase(cat);

        if (hasQuery && hasCategory) {
            result = foods.findByNameContainingIgnoreCaseOrDescriptionContainingIgnoreCaseOrderByNameAsc(q, q)
                    .stream()
                    .filter(f -> f.getCategory().equalsIgnoreCase(cat))
                    .toList();
        } else if (hasCategory) {
            result = foods.findByCategoryIgnoreCaseOrderByNameAsc(cat);
        } else if (hasQuery) {
            result = foods.findByNameContainingIgnoreCaseOrDescriptionContainingIgnoreCaseOrderByNameAsc(q, q);
        } else {
            result = foods.findAllByOrderByCategoryAscNameAsc();
        }

        return result.stream().map(FoodDto::from).toList();
    }

    public FoodDto get(Long id) {
        return foods.findById(id)
                .map(FoodDto::from)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Food item not found"));
    }

    public List<String> categories() {
        return CATEGORY_ORDER;
    }
}
