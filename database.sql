-- =====================================================================
--  KIOT COLLEGE CANTEEN PRE-ORDER SYSTEM
--  Manual database setup script (MySQL 8.0+)
--
--  NOTE: You normally do NOT need to run this file.
--  The application uses spring.jpa.hibernate.ddl-auto=update, so
--  Hibernate creates all tables automatically and DataSeeder inserts the
--  demo users and the 17 food items on every startup (idempotently).
--
--  This script exists as a fallback / for manual inspection and grading.
--  Usage:  mysql -u root -p < database.sql
-- =====================================================================

CREATE DATABASE IF NOT EXISTS kiot_canteen
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE kiot_canteen;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS food_items;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. USERS
-- ---------------------------------------------------------------------
CREATE TABLE users (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  name          VARCHAR(100) NOT NULL,
  email         VARCHAR(150) NOT NULL,
  password_hash VARCHAR(100) NOT NULL,          -- BCrypt hash, never exposed by the API
  student_id    VARCHAR(50),
  phone         VARCHAR(20),
  role          VARCHAR(20)  NOT NULL DEFAULT 'STUDENT',
  created_at    DATETIME(6)  NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 2. FOOD_ITEMS
-- ---------------------------------------------------------------------
CREATE TABLE food_items (
  id             BIGINT        NOT NULL AUTO_INCREMENT,
  name           VARCHAR(100)  NOT NULL,
  description    VARCHAR(500),
  price          DECIMAL(8,2)  NOT NULL,
  category       VARCHAR(40)   NOT NULL,
  image_url      VARCHAR(500),
  available      BIT(1)        NOT NULL DEFAULT b'1',
  prep_time_mins INT           NOT NULL DEFAULT 15,
  is_veg         BIT(1)        NOT NULL DEFAULT b'1',
  created_at     DATETIME(6)   NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 3. ORDERS
--    order_code format: KIOT-CAN-<year>-<00001>
-- ---------------------------------------------------------------------
CREATE TABLE orders (
  id              BIGINT        NOT NULL AUTO_INCREMENT,
  order_code      VARCHAR(40)   NOT NULL,
  user_id         BIGINT        NOT NULL,
  total_amount    DECIMAL(10,2) NOT NULL,
  pickup_date     DATE          NOT NULL,
  pickup_slot     VARCHAR(30)   NOT NULL,
  payment_method  ENUM('UPI','CARD','CASH')      NOT NULL,
  payment_status  ENUM('PAID','PENDING')          NOT NULL,
  order_status    ENUM('CONFIRMED','PREPARING','READY','COMPLETED','CANCELLED') NOT NULL,
  created_at      DATETIME(6)   NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_orders_code (order_code),
  KEY idx_orders_user (user_id),
  CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 4. ORDER_ITEMS
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
  id           BIGINT        NOT NULL AUTO_INCREMENT,
  order_id     BIGINT        NOT NULL,
  food_item_id BIGINT,
  item_name    VARCHAR(100)  NOT NULL,          -- name copied at order time
  unit_price   DECIMAL(8,2)  NOT NULL,
  quantity     INT           NOT NULL,
  line_total   DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_items_order (order_id),
  KEY idx_items_food (food_item_id),
  CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES orders (id),
  CONSTRAINT fk_items_food  FOREIGN KEY (food_item_id) REFERENCES food_items (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- 5. PAYMENTS
-- ---------------------------------------------------------------------
CREATE TABLE payments (
  id         BIGINT        NOT NULL AUTO_INCREMENT,
  order_id   BIGINT        NOT NULL,
  method     ENUM('UPI','CARD','CASH') NOT NULL,
  status     ENUM('PAID','PENDING')     NOT NULL,
  amount     DECIMAL(10,2) NOT NULL,
  reference  VARCHAR(60),
  created_at DATETIME(6)   NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_payment_order (order_id),
  CONSTRAINT fk_payment_order FOREIGN KEY (order_id) REFERENCES orders (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
--  DEMO DATA
--  The application seeds this automatically; included here for reference.
-- =====================================================================

-- Passwords are BCrypt hashes (plaintext shown only in the comment).
-- student@kiot.edu -> canteen123
-- demo@kiot.edu     -> demo1234
INSERT INTO users (name, email, password_hash, student_id, phone, role, created_at) VALUES
('Hariharan P','student@kiot.edu','$2a$10$n89oRHnht7W3TC3mhdBWTOGC5.2h2lpPegxbYmI9iq2tCSQhd0yOG','22CS014','9876543210','STUDENT', NOW(6)),
('Demo Student','demo@kiot.edu',    '$2a$10$sZcOD6NEZOoDtsq.dyRbleZ3UEcf9oLByHbqNJmG8UfkRBucEI2HS','22CS001','9000000000','STUDENT', NOW(6));

INSERT INTO food_items (name, description, price, category, image_url, available, prep_time_mins, is_veg, created_at) VALUES
('Sambar Rice',  'Steamed rice served with traditional sambar and chutney.',              35.00,'Rice',   'https://thumb.wikimedia.org/wikipedia/commons/thumb/4/42/Lunch_In_Progress_-_Rice_mixed_with_onion_sambar.jpg/960px-Lunch_In_Progress_-_Rice_mixed_with_onion_sambar.jpg', b'1',12,b'1',NOW(6)),
('Curd Rice',    'Light and comforting curd rice with pickle and papad.',                 30.00,'Rice',   'https://thumb.wikimedia.org/wikipedia/commons/thumb/7/77/Curd_rice_in_ICH_Bhopal.jpg/960px-Curd_rice_in_ICH_Bhopal.jpg', b'1',10,b'1',NOW(6)),
('Chicken Rice', 'Basmati rice cooked with tender chicken and spices.',                  60.00,'Rice',   'https://thumb.wikimedia.org/wikipedia/commons/thumb/0/0f/Hainanese_chicken_rice_%28in_Macau%29.jpg/960px-Hainanese_chicken_rice_%28in_Macau%29.jpg', b'1',18,b'0',NOW(6)),
('Fried Rice',   'Wok-tossed rice with vegetables and signature seasoning.',             55.00,'Rice',   'https://thumb.wikimedia.org/wikipedia/commons/thumb/3/30/Fried_rice_with_chicken_and_egg.jpg/960px-Fried_rice_with_chicken_and_egg.jpg', b'1',18,b'0',NOW(6)),
('Veg Biryani',  'Aromatic basmati layered with vegetables and served with raita.',       75.00,'Biryani','https://thumb.wikimedia.org/wikipedia/commons/thumb/0/09/Vegetable_Biryani_IMG_001.jpg/960px-Vegetable_Biryani_IMG_001.jpg', b'1',22,b'1',NOW(6)),
('Egg Biryani',  'Biryani cooked with boiled eggs and mint.',                            85.00,'Biryani','https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c8/Hyderabadi_egg_biryani.jpg/960px-Hyderabadi_egg_biryani.jpg', b'1',22,b'0',NOW(6)),
('Chicken Biryani','Signature KIOT biryani with slow-cooked chicken.',                  120.00,'Biryani','https://thumb.wikimedia.org/wikipedia/commons/thumb/5/5b/Chicken_biriyani-_My_cafe_restaurant_-_Meghalaya_DSC_009.jpg/960px-Chicken_biriyani-_My_cafe_restaurant_-_Meghalaya_DSC_009.jpg', b'1',25,b'0',NOW(6)),
('Veg Noodles',  'Stir-fried noodles with crunchy vegetables.',                          50.00,'Noodles','https://thumb.wikimedia.org/wikipedia/commons/thumb/2/22/Noodles-Veg_Noodles.JPG/960px-Noodles-Veg_Noodles.JPG', b'1',15,b'1',NOW(6)),
('Chicken Noodles','Noodles wok-tossed with sliced chicken.',                            70.00,'Noodles','https://thumb.wikimedia.org/wikipedia/commons/thumb/9/9b/Chicken_noodles_with_sauce.jpg/960px-Chicken_noodles_with_sauce.jpg', b'1',18,b'0',NOW(6)),
('Plain Parotta','Flaky layered parotta, freshly made to order.',                        20.00,'Parotta','https://thumb.wikimedia.org/wikipedia/commons/thumb/f/f8/Parotta_from_Kerala.jpg/960px-Parotta_from_Kerala.jpg', b'1', 8,b'1',NOW(6)),
('Kothu Parotta','Parotta shredded and tossed with egg and vegetables.',                  55.00,'Parotta','https://upload.wikimedia.org/wikipedia/commons/f/f5/Kothu_Parotta_%28Chicken%29_as_served_in_Tamil_Nadu%2C_India.jpg', b'1',20,b'0',NOW(6)),
('Masala Dosa',  'Crisp dosa with spiced potato masala and chutneys.',                    50.00,'Dosa',   'https://thumb.wikimedia.org/wikipedia/commons/thumb/6/6e/Masala_dosa_2.jpg/960px-Masala_dosa_2.jpg', b'1',15,b'1',NOW(6)),
('Egg Dosa',     'Dosa topped with a soft egg and onions.',                               60.00,'Dosa',   'https://thumb.wikimedia.org/wikipedia/commons/thumb/d/d8/Egg_Dosa-MB42.jpg/960px-Egg_Dosa-MB42.jpg', b'1',18,b'0',NOW(6)),
('Idli',         'Steamed idli with sambar and coconut chutney.',                         20.00,'Idli',   'https://thumb.wikimedia.org/wikipedia/commons/thumb/8/8a/Idli_sambar.2.jpg/960px-Idli_sambar.2.jpg', b'1', 8,b'1',NOW(6)),
('Pongal',       'Pepper-cumin pongal served with chutney and papad.',                     35.00,'Tiffin', 'https://thumb.wikimedia.org/wikipedia/commons/thumb/2/21/Ven_pongal_with_sambar_and_chutney.jpg/960px-Ven_pongal_with_sambar_and_chutney.jpg', b'1',12,b'1',NOW(6)),
('Vada',         'Crisp medu vada with sambar and chutney.',                              25.00,'Tiffin', 'https://thumb.wikimedia.org/wikipedia/commons/thumb/f/fd/Medu_Vada_and_Sambhar.JPG/960px-Medu_Vada_and_Sambhar.JPG', b'1',10,b'1',NOW(6)),
('Poori',        'Flaky poori with potato curry and chutney.',                            25.00,'Tiffin', 'https://thumb.wikimedia.org/wikipedia/commons/thumb/1/18/Poori_with_spiced_potato_gravy.jpg/960px-Poori_with_spiced_potato_gravy.jpg', b'1',12,b'1',NOW(6));

-- =====================================================================
--  CATEGORIES
--    All | Rice | Biryani | Noodles | Parotta | Dosa | Idli | Tiffin
--
--  PICKUP SLOTS (configured in OrderService)
--    12:00 - 12:15 | 12:15 - 12:30 | 12:30 - 12:45 | 01:00 - 01:15 | 01:15 - 01:30
--
--  PAYMENT LOGIC
--    UPI, CARD  -> payment_status = PAID
--    CASH       -> payment_status = PENDING
--    order_status always starts as CONFIRMED
-- =====================================================================
