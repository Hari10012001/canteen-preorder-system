package com.kiot.canteen.config;

import com.kiot.canteen.entity.FoodItem;
import com.kiot.canteen.entity.User;
import com.kiot.canteen.repository.FoodItemRepository;
import com.kiot.canteen.repository.UserRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Objects;

@Component
public class DataSeeder implements CommandLineRunner {

    private final UserRepository users;
    private final FoodItemRepository foods;
    private final PasswordEncoder encoder;

    public DataSeeder(UserRepository users, FoodItemRepository foods, PasswordEncoder encoder) {
        this.users = users;
        this.foods = foods;
        this.encoder = encoder;
    }

    @Override
    @Transactional
    public void run(String... args) {
        seedUsers();
        seedFoods();
    }

    private void seedUsers() {
        if (!users.existsByEmailIgnoreCase("student@kiot.edu")) {
            User u = new User();
            u.setName("Hariharan P");
            u.setEmail("student@kiot.edu");
            u.setStudentId("22CS014");
            u.setPhone("9876543210");
            u.setRole("STUDENT");
            u.setPasswordHash(encoder.encode("canteen123"));
            users.save(u);
            System.out.println("[seed] created demo user student@kiot.edu (default password is documented in README.md)");
        }
        if (!users.existsByEmailIgnoreCase("demo@kiot.edu")) {
            User u = new User();
            u.setName("Demo Student");
            u.setEmail("demo@kiot.edu");
            u.setStudentId("22CS001");
            u.setPhone("9000000000");
            u.setRole("STUDENT");
            u.setPasswordHash(encoder.encode("demo1234"));
            users.save(u);
            System.out.println("[seed] created demo user demo@kiot.edu (default password is documented in README.md)");
        }
    }

    private void seedFoods() {
        List<FoodItem> menu = List.of(
                food("Sambar Rice", "Steamed rice served with traditional sambar and chutney.", "35", "Rice", 12, true,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/5/58/Sambhar_Rice.jpg/960px-Sambhar_Rice.jpg"),
                food("Curd Rice", "Light and comforting curd rice with pickle and papad.", "30", "Rice", 10, true,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/7/77/Curd_rice_in_ICH_Bhopal.jpg/960px-Curd_rice_in_ICH_Bhopal.jpg"),
                food("Chicken Rice", "Basmati rice cooked with tender chicken and spices.", "60", "Rice", 18, false,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/0/07/Chicken_Curry_%26_Rice_%283%29.jpg/960px-Chicken_Curry_%26_Rice_%283%29.jpg"),
                food("Fried Rice", "Wok-tossed rice with vegetables and signature seasoning.", "55", "Rice", 18, false,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/3/30/Fried_rice_with_chicken_and_egg.jpg/960px-Fried_rice_with_chicken_and_egg.jpg"),

                food("Veg Biryani", "Aromatic basmati layered with vegetables and served with raita.", "75", "Biryani", 22, true,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/0/09/Vegetable_Biryani_IMG_001.jpg/960px-Vegetable_Biryani_IMG_001.jpg"),
                food("Egg Biryani", "Biryani cooked with boiled eggs and mint.", "85", "Biryani", 22, false,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c8/Hyderabadi_egg_biryani.jpg/960px-Hyderabadi_egg_biryani.jpg"),
                food("Chicken Biryani", "Signature KIOT biryani with slow-cooked chicken.", "120", "Biryani", 25, false,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/3/3d/Biryani_from_Hotel_Sapphire%2C_Thrissur.jpg/960px-Biryani_from_Hotel_Sapphire%2C_Thrissur.jpg"),

                food("Veg Noodles", "Stir-fried noodles with crunchy vegetables.", "50", "Noodles", 15, true,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/2/22/Noodles-Veg_Noodles.JPG/960px-Noodles-Veg_Noodles.JPG"),
                food("Chicken Noodles", "Noodles wok-tossed with sliced chicken.", "70", "Noodles", 18, false,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/9/9b/Chicken_noodles_with_sauce.jpg/960px-Chicken_noodles_with_sauce.jpg"),

                food("Plain Parotta", "Flaky layered parotta, freshly made to order.", "20", "Parotta", 8, true,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/f/f8/Parotta_from_Kerala.jpg/960px-Parotta_from_Kerala.jpg"),
                food("Kothu Parotta", "Parotta shredded and tossed with egg and vegetables.", "55", "Parotta", 20, false,
                        "https://upload.wikimedia.org/wikipedia/commons/f/f5/Kothu_Parotta_%28Chicken%29_as_served_in_Tamil_Nadu%2C_India.jpg"),

                food("Masala Dosa", "Crisp dosa with spiced potato masala and chutneys.", "50", "Dosa", 15, true,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/6/6e/Masala_dosa_2.jpg/960px-Masala_dosa_2.jpg"),
                food("Egg Dosa", "Dosa topped with a soft egg and onions.", "60", "Dosa", 18, false,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/d/d8/Egg_Dosa-MB42.jpg/960px-Egg_Dosa-MB42.jpg"),

                food("Idli", "Steamed idli with sambar and coconut chutney.", "20", "Idli", 8, true,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/c/ce/Idli_sambar_and_coconut_chutney.jpg/960px-Idli_sambar_and_coconut_chutney.jpg"),

                food("Pongal", "Pepper-cumin pongal served with chutney and papad.", "35", "Tiffin", 12, true,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/2/21/Ven_pongal_with_sambar_and_chutney.jpg/960px-Ven_pongal_with_sambar_and_chutney.jpg"),
                food("Vada", "Crisp medu vada with sambar and chutney.", "25", "Tiffin", 10, true,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/f/fd/Medu_Vada_and_Sambhar.JPG/960px-Medu_Vada_and_Sambhar.JPG"),
                food("Poori", "Flaky poori with potato curry and chutney.", "25", "Tiffin", 12, true,
                        "https://thumb.wikimedia.org/wikipedia/commons/thumb/1/18/Poori_with_spiced_potato_gravy.jpg/960px-Poori_with_spiced_potato_gravy.jpg")
        );

        int added = 0;
        int updated = 0;
        for (FoodItem f : menu) {
            if (!foods.existsByNameIgnoreCase(f.getName())) {
                foods.save(f);
                added++;
                continue;
            }
            FoodItem existing = foods.findByNameIgnoreCase(f.getName()).get();
            if (!Objects.equals(existing.getImageUrl(), f.getImageUrl())) {
                existing.setImageUrl(f.getImageUrl());
                foods.save(existing);
                updated++;
            }
        }
        if (added > 0) {
            System.out.println("[seed] inserted " + added + " food items");
        }
        if (updated > 0) {
            System.out.println("[seed] refreshed " + updated + " food item image(s)");
        }
    }

    private FoodItem food(String name, String desc, String price, String category,
                          int prepMins, boolean veg, String imageUrl) {
        FoodItem f = new FoodItem();
        f.setName(name);
        f.setDescription(desc);
        f.setPrice(new BigDecimal(price));
        f.setCategory(category);
        f.setImageUrl(imageUrl);
        f.setPrepTimeMins(prepMins);
        f.setVeg(veg);
        f.setAvailable(true);
        return f;
    }
}
