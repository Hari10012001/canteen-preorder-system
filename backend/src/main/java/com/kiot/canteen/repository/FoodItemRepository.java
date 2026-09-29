package com.kiot.canteen.repository;

import com.kiot.canteen.entity.FoodItem;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FoodItemRepository extends JpaRepository<FoodItem, Long> {

    List<FoodItem> findAllByOrderByCategoryAscNameAsc();

    List<FoodItem> findByNameContainingIgnoreCaseOrDescriptionContainingIgnoreCaseOrderByNameAsc(String name, String desc);

    List<FoodItem> findByCategoryIgnoreCaseOrderByNameAsc(String category);

    boolean existsByNameIgnoreCase(String name);

    java.util.Optional<FoodItem> findByNameIgnoreCase(String name);
}
