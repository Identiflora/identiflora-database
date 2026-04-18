CREATE DATABASE IF NOT EXISTS identiflora_db;

USE identiflora_db;

CREATE TABLE IF NOT EXISTS user (
  user_id int
    AUTO_INCREMENT,
  username varchar(225) NOT NULL,
  email varchar(255) NOT NULL,
  password_hash varchar(255),
  phone varchar(255),
  region varchar(255),
  global_points int NOT NULL DEFAULT 0,
  time_joined timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  external_login BOOLEAN DEFAULT 0,
  is_otp BOOLEAN DEFAULT 0,
  selected_badge varchar(255),

  INDEX idx_user_points (user_id, global_points),

  PRIMARY KEY (user_id),
  UNIQUE (username),
  UNIQUE (email),
  UNIQUE (phone)
);

-- log of one time password (otp) requests and attempts at entering that otp
CREATE TABLE IF NOT EXISTS user_otp_attempt (
  user_id int,
  created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  otp_attempt_count tinyint NOT NULL DEFAULT 0,
  external_user_attempt BOOLEAN DEFAULT 0,

  INDEX idx_user_attempts (user_id, created_at),

  CONSTRAINT otp_user 
    FOREIGN KEY (user_id) 
    REFERENCES user(user_id) 
    ON DELETE CASCADE
);

-- created when photo is submitted from user
CREATE TABLE IF NOT EXISTS identification_submission (
  identification_id int 
    AUTO_INCREMENT,
  img_url varchar(512) NOT NULL,
  user_id int, 
  time_submitted timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  latitude float,
  longitude float,

  PRIMARY KEY (identification_id),
  FOREIGN KEY (user_id)
    REFERENCES user(user_id)
    ON DELETE CASCADE
);

-- each plant species the model is capable of identifying
CREATE TABLE IF NOT EXISTS plant_species (
  species_id int
    AUTO_INCREMENT,
  common_name varchar(255),
  scientific_name varchar(255) NOT NULL,
  genus varchar(255),
  img_url varchar(512) NOT NULL,

  PRIMARY KEY (species_id),
  UNIQUE (img_url)
);

-- specifies a unique option for the result of identification
CREATE TABLE IF NOT EXISTS identification_option (
  option_id int 
    AUTO_INCREMENT,
  identification_id int NOT NULL,
  species_id int NOT NULL,
  option_rank tinyint UNSIGNED NOT NULL,

  PRIMARY KEY (option_id),

  FOREIGN KEY (identification_id)
    REFERENCES identification_submission(identification_id)
    ON DELETE CASCADE,

  FOREIGN KEY (species_id)
    REFERENCES plant_species(species_id)
    ON DELETE CASCADE,

  UNIQUE (identification_id, option_rank),
  UNIQUE (identification_id, species_id),
  INDEX (identification_id, option_id)
);

-- contains identification options
CREATE TABLE IF NOT EXISTS identification_result (
  identification_id int,
  option_id int NOT NULL,
  user_id int NOT NULL,

  PRIMARY KEY (identification_id),

  FOREIGN KEY (identification_id)
    REFERENCES identification_submission(identification_id)
    ON DELETE CASCADE,

  FOREIGN KEY (identification_id, option_id)
    REFERENCES identification_option(identification_id, option_id)
    ON DELETE CASCADE,

  FOREIGN KEY (user_id)
    REFERENCES user(user_id)
    ON DELETE CASCADE
);

-- friends table 
CREATE TABLE IF NOT EXISTS user_friend (
  user_id INT NOT NULL,
  friend_user_id INT NOT NULL,
  time_added TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (user_id, friend_user_id),

  FOREIGN KEY (user_id)
    REFERENCES user(user_id)
    ON DELETE CASCADE,

  FOREIGN KEY (friend_user_id)
    REFERENCES user(user_id)
    ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS incorrect_identification (
  identification_id int,
  correct_species_id int,
  incorrect_species_id int,
  time_submitted timestamp,

  PRIMARY KEY (identification_id),

  FOREIGN KEY (identification_id, incorrect_species_id)
    REFERENCES identification_option(identification_id, species_id)
    ON DELETE CASCADE,

  FOREIGN KEY (identification_id)
    REFERENCES identification_submission(identification_id)
    ON DELETE CASCADE,

  FOREIGN KEY (correct_species_id)
    REFERENCES plant_species(species_id)
    ON DELETE CASCADE,

  FOREIGN KEY (incorrect_species_id)
    REFERENCES plant_species(species_id)
    ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS friendships (
  requester_id INT NOT NULL,
  addressee_id INT NOT NULL,
  status ENUM('pending','accepted','blocked') NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (requester_id, addressee_id),

  CONSTRAINT chk_not_self CHECK (requester_id <> addressee_id),

  FOREIGN KEY (requester_id)
    REFERENCES user(user_id)
    ON DELETE CASCADE,

  FOREIGN KEY (addressee_id)
    REFERENCES user(user_id)
    ON DELETE CASCADE
);

-- Stored procedures and functions
delimiter //

CREATE PROCEDURE IF NOT EXISTS check_ident_id_exists (IN ident_id_in int)
  BEGIN
    SELECT identification_id FROM identification_submission
    WHERE identification_id = ident_id_in;
  END//

CREATE PROCEDURE IF NOT EXISTS check_species_id_exists (IN species_id_in int)
  BEGIN
    SELECT species_id FROM plant_species
    WHERE species_id = species_id_in;
  END//

CREATE PROCEDURE IF NOT EXISTS check_incorrect_sub_exists (IN ident_id_in int)
  BEGIN
    SELECT identification_id FROM incorrect_identification
    WHERE identification_id = ident_id_in;
  END//

CREATE PROCEDURE IF NOT EXISTS check_plant_species_exists (IN scientific_name_in varchar(255))
  BEGIN 
    SELECT scientific_name FROM plant_species 
    WHERE scientific_name = scientific_name_in;
  END//
  
CREATE PROCEDURE IF NOT EXISTS add_incorrect_id (IN ident_id_in int, IN correct_species_id_in int, IN inc_species_id_in int)
  BEGIN
    INSERT INTO incorrect_identification
      (identification_id, correct_species_id, incorrect_species_id, time_submitted)
      VALUES (ident_id_in, correct_species_id_in, inc_species_id_in, NOW());
  END//

CREATE PROCEDURE IF NOT EXISTS add_plant_species (
  IN common_name_in varchar(255),
  IN scientific_name_in varchar(255),
  IN genus_in varchar(255),
  IN img_url_in varchar(512)
)
  BEGIN
    INSERT INTO plant_species
      (common_name, scientific_name, genus, img_url)
      VALUES (common_name_in, scientific_name_in, genus_in, img_url_in);
  END//

CREATE PROCEDURE IF NOT EXISTS add_plant_species_img_url (IN sci_name varchar(255), IN img_url_in varchar(512))
  BEGIN
    UPDATE plant_species SET img_url = img_url_in 
    WHERE scientific_name = sci_name;
  END//

CREATE PROCEDURE IF NOT EXISTS get_plant_species_img_url (IN sci_name varchar(255))
  BEGIN
    SELECT img_url FROM plant_species
    WHERE scientific_name = sci_name;
  END//
  
CREATE PROCEDURE IF NOT EXISTS check_username_exists (IN username_in varchar(225))
  BEGIN
    SELECT username FROM user
    WHERE username = username_in;
  END//

CREATE PROCEDURE IF NOT EXISTS check_user_email_exists (IN user_email_in varchar(225))
  BEGIN
    SELECT email FROM user
    WHERE email = user_email_in;
  END//

CREATE PROCEDURE IF NOT EXISTS check_user_password_hash_exists (IN user_password_in varchar(225))
  BEGIN
    SELECT password_hash FROM user
    WHERE password_hash = user_password_in;
  END//

DROP PROCEDURE IF EXISTS add_user//
CREATE PROCEDURE IF NOT EXISTS add_user (IN user_email_in varchar(225), IN username_in varchar(225), IN region_in varchar(255), IN user_password_in varchar(225))
  BEGIN
    INSERT INTO user
      (username, email, password_hash, time_joined, region)
      VALUES (username_in, user_email_in, user_password_in, NOW(), region_in);

    -- Get user ID for new user
    SELECT user_id FROM user
    WHERE username = username_in AND email = user_email_in AND password_hash = user_password_in;
  END//

CREATE PROCEDURE IF NOT EXISTS add_external_user (IN user_email_in varchar(225), IN username_in varchar(225), IN region_in varchar(255))
  BEGIN
    INSERT INTO user
      (username, email, password_hash, time_joined, external_login, region)
      VALUES (username_in, user_email_in, '', NOW(), 1, region_in);

    -- Get user ID for new user
    SELECT user_id FROM user
    WHERE username = username_in AND email = user_email_in AND external_login = 1;
  END//

CREATE PROCEDURE IF NOT EXISTS get_global_leaderboard_info (IN leaderboard_size int)
  BEGIN
    SELECT user_id, username, global_points, selected_badge FROM user 
    ORDER BY global_points DESC LIMIT leaderboard_size;
  END//

CREATE PROCEDURE IF NOT EXISTS get_regional_leaderboard_info (IN user_id_in int, IN leaderboard_size int)
  BEGIN
    SELECT user_id, username, global_points, selected_badge FROM user 
    WHERE region IN (SELECT region FROM user WHERE user_id = user_id_in) 
    ORDER BY global_points DESC LIMIT leaderboard_size;
  END//

CREATE PROCEDURE IF NOT EXISTS get_friends_leaderboard_info (IN user_id_in int, IN leaderboard_size int)
  BEGIN
    SELECT
      u.user_id,
      u.username,
      u.global_points,
      u.selected_badge
    FROM friendships f
    JOIN user u
      ON u.user_id = CASE
        WHEN f.requester_id = user_id_in THEN f.addressee_id
        ELSE f.requester_id
      END
    WHERE (f.requester_id = user_id_in OR f.addressee_id = user_id_in)
      AND f.status = 'accepted'
    ORDER BY u.global_points DESC LIMIT leaderboard_size;
  END//

CREATE PROCEDURE IF NOT EXISTS login_user (IN user_email_in varchar(225))
  BEGIN
    SELECT user_id, password_hash, external_login FROM user
    WHERE email = user_email_in;
  END//

CREATE PROCEDURE IF NOT EXISTS get_num_users ()
  BEGIN
    SELECT COUNT(*) FROM user;
  END//

CREATE PROCEDURE IF NOT EXISTS add_user_global_points(IN user_id_in int, IN add_points_in int)
  BEGIN
    UPDATE user SET global_points = global_points + add_points_in 
    WHERE user_id = user_id_in;
  END//

CREATE PROCEDURE IF NOT EXISTS set_user_external_login(IN user_id_in int)
  BEGIN
    UPDATE user SET external_login = 1
    WHERE user_id = user_id_in;
  END//

CREATE PROCEDURE IF NOT EXISTS otp_requested (IN user_email_in varchar(225), IN otp_in varchar(225))
  BEGIN
    DECLARE success, id int;
    DECLARE external_flag BOOLEAN;

    -- Default (no user exists)
    SET success = -1;

    -- Save user ID locally
    SELECT user_id INTO id FROM user
    WHERE email = user_email_in;

    IF id IS NOT NULL THEN
      -- Save external flag locally
      SELECT external_login INTO external_flag FROM user
      WHERE user_id = id;

      -- Update user password hash to be hashed OTP if user is not external
      IF external_flag < 1 THEN
        -- Log non-external user OTP request
        INSERT INTO user_otp_attempt
          (user_id, created_at)
          VALUES (id, NOW());

        UPDATE user SET password_hash = otp_in, is_otp = 1
        WHERE user_id = id;

        -- User exists and is valid (1)
        SET success = 1;
      ELSE
        -- Log external user OTP request
        INSERT INTO user_otp_attempt
          (user_id, created_at, external_user_attempt)
          VALUES (id, NOW(), 1);
        
        -- User exists, but is invalid (0)
        SET success = 0;
      END IF;
    END IF;

    -- Return process result
    SELECT success AS result;
  END//

CREATE PROCEDURE IF NOT EXISTS verify_otp (IN otp_exp_time_in int, IN user_email_in varchar(225))
  BEGIN
    DECLARE success int;
    DECLARE id int;
    DECLARE has_otp BOOLEAN;
    DECLARE otp varchar(225);
    DECLARE stored_time timestamp;

    -- Default (has no OTP or OTP doesn't match)
    SET success = -1;

    -- Get user id and otp bool
    SELECT user_id, is_otp, password_hash INTO id, has_otp, otp FROM user WHERE email = user_email_in;

    IF has_otp THEN
      -- OTP exists, but may be expired
      SET success = 0;

      -- Find OTP that was most recently created (the one stored for user password)
      SELECT created_at INTO stored_time FROM user_otp_attempt 
      WHERE user_id = id ORDER BY created_at DESC LIMIT 1;

      -- Increment OTP attempt count for this OTP
      UPDATE user_otp_attempt SET otp_attempt_count = otp_attempt_count + 1
      WHERE user_id = id AND created_at = stored_time;

      -- Check experation time
      IF TIMESTAMPDIFF(MINUTE, stored_time, NOW()) < otp_exp_time_in THEN
        -- OTP is not expired
        SET success = 1;
      END IF;
    END IF;

    SELECT success AS result, otp AS otp;
  END//

CREATE PROCEDURE IF NOT EXISTS replace_otp (IN new_password_hash varchar(225), IN user_email_in varchar(225))
  BEGIN
    UPDATE user SET password_hash = new_password_hash, is_otp = 0 WHERE email = user_email_in;
  END//

-- friends procedure
    CREATE PROCEDURE IF NOT EXISTS check_friend_exists (IN user_id_in INT, IN friend_user_id_in INT)
BEGIN
  SELECT user_id FROM user_friend
  WHERE user_id = user_id_in AND friend_user_id = friend_user_id_in;
END//

CREATE PROCEDURE IF NOT EXISTS add_friend (IN user_id_in INT, IN friend_user_id_in INT)
BEGIN
  INSERT INTO user_friend (user_id, friend_user_id, time_added)
  VALUES (user_id_in, friend_user_id_in, NOW());
END//

-- CREATE PROCEDURE IF NOT EXISTS get_friends (IN user_id_in INT)
-- BEGIN
--   SELECT friend_user_id
--   FROM user_friend
--   WHERE user_id = user_id_in
--   ORDER BY time_added DESC;
-- END//
  
-- for geting a species id from scientific name. Needed for submitting an incorrect identification. 
CREATE PROCEDURE IF NOT EXISTS get_species_id (IN scientific_name_in varchar(255))
  BEGIN
    SELECT species_id FROM plant_species WHERE scientific_name = scientific_name_in;
  END//

-- gets a users global points from their user id
CREATE PROCEDURE IF NOT EXISTS get_user_points(IN user_id_in INT)
  BEGIN 
    SELECT global_points FROM user WHERE user_id = user_id_in;
  END//

-- gets a users username from their user id
CREATE PROCEDURE IF NOT EXISTS get_username(IN user_id_in INT)
  BEGIN 
    SELECT username FROM user WHERE user_id = user_id_in;
  END//

CREATE PROCEDURE IF NOT EXISTS add_friend_by_username (
  IN requester_id_in INT,
  IN addressee_username_in VARCHAR(225)
)
BEGIN
  DECLARE addressee_id INT;

  SELECT user_id INTO addressee_id
  FROM user
  WHERE username = addressee_username_in
  LIMIT 1;

  IF addressee_id IS NULL THEN
    SELECT 'user_not_found' AS error;
  ELSEIF addressee_id = requester_id_in THEN
    SELECT 'cannot_add_self' AS error;
  ELSE
    INSERT INTO friendships (requester_id, addressee_id, status)
    VALUES (requester_id_in, addressee_id, 'pending')
    ON DUPLICATE KEY UPDATE
      status = VALUES(status),
      created_at = CURRENT_TIMESTAMP;

    SELECT 'ok' AS result, addressee_id AS addressee_user_id;
  END IF;
END//

CREATE PROCEDURE IF NOT EXISTS get_friends (IN user_id_in INT)
BEGIN
  SELECT
    u.user_id,
    u.username,
    u.email,
    u.global_points,
    u.time_joined
  FROM friendships f
  JOIN user u
    ON u.user_id = CASE
      WHEN f.requester_id = user_id_in THEN f.addressee_id
      ELSE f.requester_id
    END
  WHERE (f.requester_id = user_id_in OR f.addressee_id = user_id_in)
    AND f.status = 'accepted';
END//

CREATE PROCEDURE IF NOT EXISTS set_user_badge(IN user_id_in int, IN badge_file_path varchar(225))
  BEGIN
    UPDATE user SET selected_badge = badge_file_path
    WHERE user_id = user_id_in;
  END//

CREATE PROCEDURE IF NOT EXISTS get_user_badge(IN user_id_in int)
  BEGIN
    SELECT selected_badge FROM user 
    WHERE user_id = user_id_in;
  END//

CREATE PROCEDURE IF NOT EXISTS get_user_region(IN user_id_in int)
  BEGIN
    SELECT region FROM user 
    WHERE user_id = user_id_in;
  END//

CREATE PROCEDURE IF NOT EXISTS update_user_email (IN user_id_in INT, IN new_email_in VARCHAR(255))
BEGIN
    UPDATE user SET email = new_email_in WHERE user_id = user_id_in;
END//

CREATE PROCEDURE IF NOT EXISTS update_user_password (IN user_id_in INT, IN new_password_in VARCHAR(255))
BEGIN
    UPDATE user SET password_hash = new_password_in, is_otp = 0 WHERE user_id = user_id_in;
END//

CREATE PROCEDURE IF NOT EXISTS delete_user (IN user_id_in INT)
BEGIN
    DELETE FROM user WHERE user_id = user_id_in;
END//

-- Creates the initial submission and returns its ID
CREATE PROCEDURE IF NOT EXISTS add_identification_submission (
  IN user_id_in INT,
  IN lat_in FLOAT,
  IN lon_in FLOAT,
  IN img_url_in VARCHAR(512)
)
BEGIN
  INSERT INTO identification_submission (user_id, latitude, longitude, img_url)
  VALUES (user_id_in, lat_in, lon_in, img_url_in);
  SELECT LAST_INSERT_ID() AS identification_id;
END//

-- Adds an identification option and returns the generated option ID
CREATE PROCEDURE IF NOT EXISTS add_identification_option (
  IN ident_id_in INT,
  IN species_id_in INT,
  IN rank_in TINYINT
)
BEGIN
  INSERT INTO identification_option (identification_id, species_id, option_rank)
  VALUES (ident_id_in, species_id_in, rank_in);
  SELECT LAST_INSERT_ID() AS option_id;
END//

-- Records the final result chosen for a submission
CREATE PROCEDURE IF NOT EXISTS add_identification_result (
  IN ident_id_in INT,
  IN user_id_in INT,
  IN option_id_in INT
)
BEGIN
  INSERT INTO identification_result (identification_id, user_id, option_id)
  VALUES (ident_id_in, user_id_in, option_id_in);
END//

-- Generalized lookup for species ID by name (supporting common or scientific)
CREATE PROCEDURE IF NOT EXISTS get_species_id_by_name (IN name_in VARCHAR(255))
BEGIN
  SELECT species_id FROM plant_species 
  WHERE scientific_name = name_in OR common_name = name_in 
  LIMIT 1;
END//

CREATE PROCEDURE IF NOT EXISTS get_user_submission_history (IN user_id_in INT)
BEGIN
    SELECT 
        s.identification_id,
        s.time_submitted,
        s.latitude,
        s.longitude,
        s.img_url AS submission_img,
        p.common_name,
        p.scientific_name,
        p.img_url AS species_img
    FROM identification_submission s
    JOIN identification_option o ON s.identification_id = o.identification_id AND o.option_rank = 1
    JOIN plant_species p ON o.species_id = p.species_id
    WHERE s.user_id = user_id_in
    ORDER BY s.time_submitted DESC;
END//
-- gets a users level from their user id - not implemented yet
delimiter ;

    IF external_flag < 1 THEN
      INSERT INTO user_otp_attempt (user_id, created_at)
      VALUES (id, NOW());

      UPDATE user
      SET password_hash = otp_in, is_otp = 1
      WHERE user_id = id;

      SET success = 1;
    ELSE
      INSERT INTO user_otp_attempt (user_id, created_at, external_user_attempt)
      VALUES (id, NOW(), 1);

      SET success = 0;
    END IF;
  END IF;

  SELECT success AS result;
END//

CREATE PROCEDURE verify_otp (
  IN otp_exp_time_in INT,
  IN user_email_in VARCHAR(225)
)
BEGIN
  DECLARE success INT;
  DECLARE id INT;
  DECLARE has_otp BOOLEAN;
  DECLARE otp VARCHAR(225);
  DECLARE stored_time TIMESTAMP;

  SET success = -1;

  SELECT user_id, is_otp, password_hash
  INTO id, has_otp, otp
  FROM user
  WHERE email = user_email_in;

  IF has_otp THEN
    SET success = 0;

    SELECT created_at INTO stored_time
    FROM user_otp_attempt
    WHERE user_id = id
    ORDER BY created_at DESC
    LIMIT 1;

    UPDATE user_otp_attempt
    SET otp_attempt_count = otp_attempt_count + 1
    WHERE user_id = id AND created_at = stored_time;

    IF TIMESTAMPDIFF(MINUTE, stored_time, NOW()) < otp_exp_time_in THEN
      SET success = 1;
    END IF;
  END IF;

  SELECT success AS result, otp AS otp;
END//

CREATE PROCEDURE replace_otp (
  IN new_password_hash VARCHAR(225),
  IN user_email_in VARCHAR(225)
)
BEGIN
  UPDATE user
  SET password_hash = new_password_hash, is_otp = 0
  WHERE email = user_email_in;
END//

CREATE PROCEDURE get_species_id (IN scientific_name_in VARCHAR(255))
BEGIN
  SELECT species_id
  FROM plant_species
  WHERE scientific_name = scientific_name_in;
END//

CREATE PROCEDURE get_user_points (IN user_id_in INT)
BEGIN
  SELECT global_points
  FROM user
  WHERE user_id = user_id_in;
END//

CREATE PROCEDURE get_username (IN user_id_in INT)
BEGIN
  SELECT username
  FROM user
  WHERE user_id = user_id_in;
END//

CREATE PROCEDURE add_friend_by_username (
  IN requester_id_in INT,
  IN addressee_username_in VARCHAR(225)
)
BEGIN
  DECLARE addressee_id INT;
  DECLARE existing_count INT DEFAULT 0;

  SELECT user_id INTO addressee_id
  FROM user
  WHERE username = addressee_username_in
  LIMIT 1;

  IF addressee_id IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'User not found';
  ELSEIF addressee_id = requester_id_in THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Cannot add yourself';
  ELSE
    SELECT COUNT(*) INTO existing_count
    FROM friendships
    WHERE
      (requester_id = requester_id_in AND addressee_id = addressee_id)
      OR
      (requester_id = addressee_id AND addressee_id = requester_id_in);

    IF existing_count > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Friendship or request already exists';
    ELSE
      INSERT INTO friendships (requester_id, addressee_id, status)
      VALUES (requester_id_in, addressee_id, 'pending');
    END IF;
  END IF;
END//

CREATE PROCEDURE get_pending_friend_requests (IN user_id_in INT)
BEGIN
  SELECT
    u.user_id,
    u.username,
    u.email,
    f.created_at
  FROM friendships f
  JOIN user u
    ON u.user_id = f.requester_id
  WHERE f.addressee_id = user_id_in
    AND f.status = 'pending'
  ORDER BY f.created_at DESC;
END//

CREATE PROCEDURE accept_friend_request (
  IN requester_id_in INT,
  IN addressee_id_in INT
)
BEGIN
  UPDATE friendships
  SET status = 'accepted'
  WHERE requester_id = requester_id_in
    AND addressee_id = addressee_id_in
    AND status = 'pending';
END//

CREATE PROCEDURE reject_friend_request (
  IN requester_id_in INT,
  IN addressee_id_in INT
)
BEGIN
  DELETE FROM friendships
  WHERE requester_id = requester_id_in
    AND addressee_id = addressee_id_in
    AND status = 'pending';
END//

CREATE PROCEDURE remove_friend (
  IN user_id_in INT,
  IN friend_id_in INT
)
BEGIN
  DELETE FROM friendships
  WHERE (
      (requester_id = user_id_in AND addressee_id = friend_id_in)
      OR
      (requester_id = friend_id_in AND addressee_id = user_id_in)
    )
    AND status = 'accepted';
END//

CREATE PROCEDURE get_friends (IN user_id_in INT)
BEGIN
  SELECT
    u.user_id,
    u.username,
    u.email,
    u.global_points,
    u.time_joined
  FROM friendships f
  JOIN user u
    ON u.user_id = CASE
      WHEN f.requester_id = user_id_in THEN f.addressee_id
      ELSE f.requester_id
    END
  WHERE (f.requester_id = user_id_in OR f.addressee_id = user_id_in)
    AND f.status = 'accepted'
  ORDER BY u.username ASC;
END//

CREATE PROCEDURE set_user_badge (
  IN user_id_in INT,
  IN badge_file_path VARCHAR(225)
)
BEGIN
  UPDATE user
  SET selected_badge = badge_file_path
  WHERE user_id = user_id_in;
END//

CREATE PROCEDURE get_user_badge (IN user_id_in INT)
BEGIN
  SELECT selected_badge
  FROM user
  WHERE user_id = user_id_in;
END//

CREATE PROCEDURE get_user_region (IN user_id_in INT)
BEGIN
  SELECT region
  FROM user
  WHERE user_id = user_id_in;
END//

CREATE PROCEDURE update_user_email (
  IN user_id_in INT,
  IN new_email_in VARCHAR(255)
)
BEGIN
  UPDATE user
  SET email = new_email_in
  WHERE user_id = user_id_in;
END//

CREATE PROCEDURE update_user_password (
  IN user_id_in INT,
  IN new_password_in VARCHAR(255)
)
BEGIN
  UPDATE user
  SET password_hash = new_password_in, is_otp = 0
  WHERE user_id = user_id_in;
END//

CREATE PROCEDURE delete_user (IN user_id_in INT)
BEGIN
  DELETE FROM user
  WHERE user_id = user_id_in;
END//

CREATE PROCEDURE add_identification_submission (
  IN user_id_in INT,
  IN lat_in FLOAT,
  IN lon_in FLOAT,
  IN img_url_in VARCHAR(512)
)
BEGIN
  INSERT INTO identification_submission (user_id, latitude, longitude, img_url)
  VALUES (user_id_in, lat_in, lon_in, img_url_in);

  SELECT LAST_INSERT_ID() AS identification_id;
END//

CREATE PROCEDURE add_identification_option (
  IN ident_id_in INT,
  IN species_id_in INT,
  IN rank_in TINYINT
)
BEGIN
  INSERT INTO identification_option (identification_id, species_id, option_rank)
  VALUES (ident_id_in, species_id_in, rank_in);

  SELECT LAST_INSERT_ID() AS option_id;
END//

CREATE PROCEDURE add_identification_result (
  IN ident_id_in INT,
  IN user_id_in INT,
  IN option_id_in INT
)
BEGIN
  INSERT INTO identification_result (identification_id, user_id, option_id)
  VALUES (ident_id_in, user_id_in, option_id_in);
END//

CREATE PROCEDURE get_species_id_by_name (IN name_in VARCHAR(255))
BEGIN
  SELECT species_id
  FROM plant_species
  WHERE scientific_name = name_in OR common_name = name_in
  LIMIT 1;
END//

CREATE PROCEDURE get_user_submission_history (IN user_id_in INT)
BEGIN
  SELECT
    s.identification_id,
    s.time_submitted,
    s.latitude,
    s.longitude,
    s.img_url AS submission_img,
    p.common_name,
    p.scientific_name,
    p.img_url AS species_img
  FROM identification_submission s
  JOIN identification_option o
    ON s.identification_id = o.identification_id
   AND o.option_rank = 1
  JOIN plant_species p
    ON o.species_id = p.species_id
  WHERE s.user_id = user_id_in
  ORDER BY s.time_submitted DESC;
END//

CREATE PROCEDURE set_username (
  IN user_id_in INT,
  IN username_in VARCHAR(225)
)
BEGIN
  UPDATE user
  SET username = username_in
  WHERE user_id = user_id_in;
END//

DELIMITER ;
