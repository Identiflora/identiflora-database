CREATE DATABASE IF NOT EXISTS identiflora_db;

USE identiflora_db;

CREATE TABLE user (
  user_id int
    AUTO_INCREMENT,
  username varchar(225) NOT NULL,
  email varchar(255) NOT NULL,
  password_hash varchar(255),
  phone varchar(255),
  global_points int NOT NULL DEFAULT 0,
  time_joined timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  external_login BOOLEAN DEFAULT 0,
  is_otp BOOLEAN DEFAULT 0,

  INDEX idx_user_points (user_id, global_points),

  PRIMARY KEY (user_id),
  UNIQUE (username),
  UNIQUE (email),
  UNIQUE (phone)
);

-- log of one time password (otp) requests and attempts at entering that otp
CREATE TABLE user_otp_attempt (
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
CREATE TABLE identification_submission (
  identification_id int 
    AUTO_INCREMENT,
  img_url varchar(512) NOT NULL,
  user_id int, 
  time_submitted timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (identification_id),
  FOREIGN KEY (user_id)
    REFERENCES user(user_id)
    ON DELETE CASCADE
);

-- each plant species the model is capable of identifying
CREATE TABLE plant_species (
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
CREATE TABLE identification_option (
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

  UNIQUE (identification_id, option_rank),-- make sure each option for a certain submission has a unique rank
  UNIQUE (identification_id, species_id),-- make sure each option for a certain submission has a unique species
  INDEX (identification_id, option_id)
);

-- contains identification options
CREATE TABLE identification_result (
  identification_id int,
  option_id int NOT NULL,
  user_id int NOT NULL,

  PRIMARY KEY (identification_id),-- guarantees at most 1 result per submission

  FOREIGN KEY (identification_id) 
    REFERENCES identification_submission(identification_id)  
    ON DELETE CASCADE,

  FOREIGN KEY (identification_id, option_id)
   REFERENCES identification_option(identification_id, option_id)-- make sure result shows an option that is associated with the correct submission
   ON DELETE CASCADE,

  FOREIGN KEY (user_id) 
    REFERENCES user(user_id)
    ON DELETE CASCADE
);

CREATE TABLE incorrect_identification (
  identification_id int,
  correct_species_id int,
  incorrect_species_id int,
  time_submitted timestamp,

  PRIMARY KEY (identification_id),

  -- make sure the incorrect species_id comes from the right source
  FOREIGN KEY (identification_id, incorrect_species_id)
    REFERENCES identification_option(identification_id, species_id)-- may eventually want to change this so it pull id_id from result
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

-- Stored procedures and functions
delimiter //

CREATE PROCEDURE check_ident_id_exists (IN ident_id_in int)
  BEGIN
    SELECT identification_id FROM identification_submission
    WHERE identification_id = ident_id_in;
  END//

CREATE PROCEDURE check_species_id_exists (IN species_id_in int)
  BEGIN
    SELECT species_id FROM plant_species
    WHERE species_id = species_id_in;
  END//

CREATE PROCEDURE check_incorrect_sub_exists (IN ident_id_in int)
  BEGIN
    SELECT identification_id FROM incorrect_identification
    WHERE identification_id = ident_id_in;
  END//

CREATE PROCEDURE check_plant_species_exists (IN scientific_name_in varchar(255))
  BEGIN 
    SELECT scientific_name FROM plant_species 
    WHERE scientific_name = scientific_name_in;
  END//
  
CREATE PROCEDURE add_incorrect_id (IN ident_id_in int, IN correct_species_id_in int, IN inc_species_id_in int)
  BEGIN
    INSERT INTO incorrect_identification
      (identification_id, correct_species_id, incorrect_species_id, time_submitted)
      VALUES (ident_id_in, correct_species_id_in, inc_species_id_in, NOW());
  END//

CREATE PROCEDURE add_plant_species (
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

CREATE PROCEDURE get_plant_species_img_url (IN sci_name varchar(255))
  BEGIN
    SELECT img_url FROM plant_species
    WHERE scientific_name = sci_name;
  END//
  
CREATE PROCEDURE check_username_exists (IN username_in varchar(225))
  BEGIN
    SELECT username FROM user
    WHERE username = username_in;
  END//

CREATE PROCEDURE check_user_email_exists (IN user_email_in varchar(225))
  BEGIN
    SELECT email FROM user
    WHERE email = user_email_in;
  END//

CREATE PROCEDURE check_user_password_hash_exists (IN user_password_in varchar(225))
  BEGIN
    SELECT password_hash FROM user
    WHERE password_hash = user_password_in;
  END//

CREATE PROCEDURE add_user (IN user_email_in varchar(225), IN username_in varchar(225), IN user_password_in varchar(225))
  BEGIN
    INSERT INTO user
      (username, email, password_hash, time_joined)
      VALUES (username_in, user_email_in, user_password_in, NOW());

    -- Get user ID for new user
    SELECT user_id FROM user
    WHERE username = username_in AND email = user_email_in AND password_hash = user_password_in;
  END//

CREATE PROCEDURE add_google_user (IN user_email_in varchar(225), IN username_in varchar(225))
  BEGIN
    INSERT INTO user
      (username, email, password_hash, time_joined, external_login)
      VALUES (username_in, user_email_in, '', NOW(), 1);

    -- Get user ID for new user
    SELECT user_id FROM user
    WHERE username = username_in AND email = user_email_in AND external_login = 1;
  END//

CREATE PROCEDURE get_global_leaderboard_info (IN leaderboard_size int)
  BEGIN
    SELECT user_id, username, global_points FROM user 
    ORDER BY global_points DESC LIMIT leaderboard_size;
  END//

CREATE PROCEDURE login_user (IN user_email_in varchar(225))
  BEGIN
    SELECT user_id, password_hash, external_login FROM user
    WHERE email = user_email_in;
  END//

CREATE PROCEDURE get_num_users ()
  BEGIN
    SELECT COUNT(*) FROM user;
  END//

CREATE PROCEDURE add_user_global_points(IN user_id_in int, IN add_points_in int)
  BEGIN
    UPDATE user SET global_points = global_points + add_points_in 
    WHERE user_id = user_id_in;
  END//

CREATE PROCEDURE set_user_external_login(IN user_id_in int)
  BEGIN
    UPDATE user SET external_login = 1
    WHERE user_id = user_id_in;
  END//

CREATE PROCEDURE otp_requested (IN user_email_in varchar(225), IN otp_in varchar(225))
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

CREATE PROCEDURE verify_otp (IN otp_exp_time_in int, IN user_email_in varchar(225))
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

CREATE PROCEDURE replace_otp (IN new_password_hash varchar(225), IN user_email_in varchar(225))
  BEGIN
    UPDATE user SET password_hash = new_password_hash, is_otp = 0 WHERE email = user_email_in;
  END//

-- for geting a species id from scientific name. Needed for submitting an incorrect identification. 
CREATE PROCEDURE get_species_id (IN scientific_name_in varchar(255))
  BEGIN
    SELECT species_id FROM plant_species WHERE scientific_name = scientific_name_in;
  END//

delimiter ;

