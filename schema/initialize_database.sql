CREATE DATABASE IF NOT EXISTS identiflora_db;

USE identiflora_db;

CREATE TABLE IF NOT EXISTS user (
  user_id INT AUTO_INCREMENT,
  username VARCHAR(225) NOT NULL,
  email VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255),
  phone VARCHAR(255),
  region VARCHAR(255),
  global_points INT NOT NULL DEFAULT 0,
  time_joined TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  external_login BOOLEAN DEFAULT 0,
  is_otp BOOLEAN DEFAULT 0,
  selected_badge VARCHAR(255),

  INDEX idx_user_points (user_id, global_points),

  PRIMARY KEY (user_id),
  UNIQUE (username),
  UNIQUE (email),
  UNIQUE (phone)
);

CREATE TABLE IF NOT EXISTS user_otp_attempt (
  user_id INT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  otp_attempt_count TINYINT NOT NULL DEFAULT 0,
  external_user_attempt BOOLEAN DEFAULT 0,

  INDEX idx_user_attempts (user_id, created_at),

  CONSTRAINT otp_user
    FOREIGN KEY (user_id)
    REFERENCES user(user_id)
    ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS identification_submission (
  identification_id INT AUTO_INCREMENT,
  img_url VARCHAR(512) NOT NULL,
  user_id INT,
  time_submitted TIMESTAMP NOT NULL,
  latitude FLOAT,
  longitude FLOAT,

  PRIMARY KEY (identification_id),
  FOREIGN KEY (user_id)
    REFERENCES user(user_id)
    ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS plant_species (
  species_id INT AUTO_INCREMENT,
  common_name VARCHAR(255),
  scientific_name VARCHAR(255) NOT NULL,
  genus VARCHAR(255),
  img_url VARCHAR(512) NOT NULL,

  PRIMARY KEY (species_id),
  UNIQUE (img_url)
);

CREATE TABLE IF NOT EXISTS identification_option (
  option_id INT AUTO_INCREMENT,
  identification_id INT NOT NULL,
  species_id INT NOT NULL,
  option_rank TINYINT UNSIGNED NOT NULL,

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

CREATE TABLE IF NOT EXISTS identification_result (
  identification_id INT,
  option_id INT NOT NULL,
  user_id INT NOT NULL,

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
  identification_id INT,
  correct_species_id INT,
  incorrect_species_id INT,
  time_submitted TIMESTAMP,

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

DELIMITER //

CREATE PROCEDURE check_ident_id_exists (IN ident_id_in INT)
BEGIN
  SELECT identification_id
  FROM identification_submission
  WHERE identification_id = ident_id_in;
END//

CREATE PROCEDURE check_species_id_exists (IN species_id_in INT)
BEGIN
  SELECT species_id
  FROM plant_species
  WHERE species_id = species_id_in;
END//

CREATE PROCEDURE check_incorrect_sub_exists (IN ident_id_in INT)
BEGIN
  SELECT identification_id
  FROM incorrect_identification
  WHERE identification_id = ident_id_in;
END//

CREATE PROCEDURE check_plant_species_exists (IN scientific_name_in VARCHAR(255))
BEGIN
  SELECT scientific_name
  FROM plant_species
  WHERE scientific_name = scientific_name_in;
END//

CREATE PROCEDURE add_incorrect_id (
  IN ident_id_in INT,
  IN correct_species_id_in INT,
  IN inc_species_id_in INT
)
BEGIN
  INSERT INTO incorrect_identification
    (identification_id, correct_species_id, incorrect_species_id, time_submitted)
  VALUES
    (ident_id_in, correct_species_id_in, inc_species_id_in, NOW());
END//

CREATE PROCEDURE add_plant_species (
  IN common_name_in VARCHAR(255),
  IN scientific_name_in VARCHAR(255),
  IN genus_in VARCHAR(255),
  IN img_url_in VARCHAR(512)
)
BEGIN
  INSERT INTO plant_species
    (common_name, scientific_name, genus, img_url)
  VALUES
    (common_name_in, scientific_name_in, genus_in, img_url_in);
END//

CREATE PROCEDURE add_plant_species_img_url (
  IN sci_name VARCHAR(255),
  IN img_url_in VARCHAR(512)
)
BEGIN
  UPDATE plant_species
  SET img_url = img_url_in
  WHERE scientific_name = sci_name;
END//

CREATE PROCEDURE get_plant_species_img_url (IN sci_name VARCHAR(255))
BEGIN
  SELECT img_url
  FROM plant_species
  WHERE scientific_name = sci_name;
END//

CREATE PROCEDURE check_username_exists (IN username_in VARCHAR(225))
BEGIN
  SELECT username
  FROM user
  WHERE username = username_in;
END//

CREATE PROCEDURE check_user_email_exists (IN user_email_in VARCHAR(225))
BEGIN
  SELECT email
  FROM user
  WHERE email = user_email_in;
END//

CREATE PROCEDURE check_user_password_hash_exists (IN user_password_in VARCHAR(225))
BEGIN
  SELECT password_hash
  FROM user
  WHERE password_hash = user_password_in;
END//

CREATE PROCEDURE add_user (
  IN user_email_in VARCHAR(225),
  IN username_in VARCHAR(225),
  IN region_in VARCHAR(255),
  IN user_password_in VARCHAR(225)
)
BEGIN
  INSERT INTO user
    (username, email, password_hash, time_joined, region)
  VALUES
    (username_in, user_email_in, user_password_in, NOW(), region_in);

  SELECT user_id
  FROM user
  WHERE username = username_in
    AND email = user_email_in
    AND password_hash = user_password_in;
END//

CREATE PROCEDURE add_external_user (
  IN user_email_in VARCHAR(225),
  IN username_in VARCHAR(225),
  IN region_in VARCHAR(255)
)
BEGIN
  INSERT INTO user
    (username, email, password_hash, time_joined, external_login, region)
  VALUES
    (username_in, user_email_in, '', NOW(), 1, region_in);

  SELECT user_id
  FROM user
  WHERE username = username_in
    AND email = user_email_in
    AND external_login = 1;
END//

CREATE PROCEDURE get_global_leaderboard_info (IN leaderboard_size INT)
BEGIN
  SELECT user_id, username, global_points, selected_badge
  FROM user
  ORDER BY global_points DESC
  LIMIT leaderboard_size;
END//

CREATE PROCEDURE get_regional_leaderboard_info (
  IN user_id_in INT,
  IN leaderboard_size INT
)
BEGIN
  SELECT user_id, username, global_points, selected_badge
  FROM user
  WHERE region IN (
    SELECT region FROM user WHERE user_id = user_id_in
  )
  ORDER BY global_points DESC
  LIMIT leaderboard_size;
END//

CREATE PROCEDURE get_friends_leaderboard_info (
  IN user_id_in INT,
  IN leaderboard_size INT
)
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
  ORDER BY u.global_points DESC
  LIMIT leaderboard_size;
END//

CREATE PROCEDURE login_user (IN user_email_in VARCHAR(225))
BEGIN
  SELECT user_id, password_hash, external_login
  FROM user
  WHERE email = user_email_in;
END//

CREATE PROCEDURE get_num_users ()
BEGIN
  SELECT COUNT(*) FROM user;
END//

CREATE PROCEDURE add_user_global_points (
  IN user_id_in INT,
  IN add_points_in INT
)
BEGIN
  UPDATE user
  SET global_points = global_points + add_points_in
  WHERE user_id = user_id_in;
END//

CREATE PROCEDURE set_user_external_login (IN user_id_in INT)
BEGIN
  UPDATE user
  SET external_login = 1
  WHERE user_id = user_id_in;
END//

CREATE PROCEDURE otp_requested (
  IN user_email_in VARCHAR(225),
  IN otp_in VARCHAR(225)
)
BEGIN
  DECLARE success INT;
  DECLARE id INT;
  DECLARE external_flag BOOLEAN;

  SET success = -1;

  SELECT user_id INTO id
  FROM user
  WHERE email = user_email_in;

  IF id IS NOT NULL THEN
    SELECT external_login INTO external_flag
    FROM user
    WHERE user_id = id;

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
    WHERE user_id = id
      AND created_at = stored_time;

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
  SET password_hash = new_password_hash,
      is_otp = 0
  WHERE email = user_email_in;
END//

CREATE PROCEDURE check_friend_exists (
  IN user_id_in INT,
  IN friend_user_id_in INT
)
BEGIN
  SELECT user_id
  FROM user_friend
  WHERE user_id = user_id_in
    AND friend_user_id = friend_user_id_in;
END//

CREATE PROCEDURE add_friend (
  IN user_id_in INT,
  IN friend_user_id_in INT
)
BEGIN
  INSERT INTO user_friend (user_id, friend_user_id, time_added)
  VALUES (user_id_in, friend_user_id_in, NOW());
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
  SET password_hash = new_password_in,
      is_otp = 0
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
  IN time_submitted_in TIMESTAMP
)
BEGIN
  INSERT INTO identification_submission (user_id, latitude, longitude, img_url, time_submitted)
  VALUES (user_id_in, lat_in, lon_in, img_url_in, time_submitted_in);

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
  WHERE scientific_name = name_in
     OR common_name = name_in
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
      requester_id = user_id_in AND addressee_id = friend_id_in
    ) OR (
      requester_id = friend_id_in AND addressee_id = user_id_in
    );
END//

DELIMITER ;
