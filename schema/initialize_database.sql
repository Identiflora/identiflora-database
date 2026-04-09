CREATE DATABASE IF NOT EXISTS identiflora_db;

USE identiflora_db;

CREATE TABLE user (
  user_id int
    AUTO_INCREMENT,
  username varchar(225) NOT NULL,
  email varchar(255) NOT NULL,
  password_hash varchar(255) NOT NULL,
  phone varchar(255),
  global_points int,
  time_joined timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (user_id),
  UNIQUE (email),
  UNIQUE (phone)
);

CREATE TABLE friendships (
  requester_id INT NOT NULL,
  addressee_id INT NOT NULL,
  requester_status ENUM('pending', 'accepted', 'rejected') NOT NULL DEFAULT 'pending',
  addressee_status ENUM('pending', 'accepted', 'rejected') NOT NULL DEFAULT 'pending',
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

CREATE PROCEDURE get_user (IN user_id_in int)
  BEGIN
    SELECT username FROM user
    WHERE user_id = user_id_in;
  END//

CREATE PROCEDURE login_user (IN user_email_in varchar(225))
  BEGIN
    SELECT user_id, password_hash FROM user
    WHERE email = user_email_in;
  END//

CREATE PROCEDURE get_num_users ()
  BEGIN
    SELECT COUNT(*) FROM user;
  END//

CREATE PROCEDURE add_friend_by_username (
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
    INSERT INTO friendships (requester_id, addressee_id, requester_status, addressee_status)
    VALUES (requester_id_in, addressee_id, 'pending', 'pending')
    ON DUPLICATE KEY UPDATE
      requester_status = VALUES(requester_status),
      addressee_status = VALUES(addressee_status),
      created_at = CURRENT_TIMESTAMP;

    SELECT 'ok' AS result, addressee_id AS addressee_user_id;
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
    AND f.requester_status = 'accepted'
    AND f.addressee_status = 'accepted';
END//

CREATE PROCEDURE accept_friend_request (
  IN requester_id_in INT,
  IN addressee_id_in INT
)
BEGIN
  -- Check if a friendship request exists and is still pending
  IF EXISTS (SELECT 1 FROM friendships 
             WHERE (requester_id = requester_id_in AND addressee_id = addressee_id_in OR 
                    requester_id = addressee_id_in AND addressee_id = requester_id_in)
             AND (requester_status = 'pending' OR addressee_status = 'pending')) THEN
    -- Update the status to 'accepted' for the user accepting the request
    UPDATE friendships
    SET 
      requester_status = IF(requester_id_in = requester_id, 'accepted', requester_status),
      addressee_status = IF(addressee_id_in = addressee_id, 'accepted', addressee_status)
    WHERE (requester_id = requester_id_in AND addressee_id = addressee_id_in OR
           requester_id = addressee_id_in AND addressee_id = requester_id_in)
      AND (requester_status = 'pending' OR addressee_status = 'pending');

    -- Check if both users have accepted the request
    IF EXISTS (SELECT 1 FROM friendships 
               WHERE requester_id = requester_id_in 
                 AND addressee_id = addressee_id_in 
                 AND requester_status = 'accepted' 
                 AND addressee_status = 'accepted') THEN
      -- Users are now friends
      SELECT 'Friendship accepted' AS result;
    ELSE
      -- Request still pending on one side
      SELECT 'Friend request still pending on one side' AS result;
    END IF;
  ELSE
    -- No pending request found
    SELECT 'No pending request found' AS error;
  END IF;
END//

delimiter ;

