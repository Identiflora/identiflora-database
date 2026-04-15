-- Ensure a clean state for test
DELETE FROM user_otp_attempt WHERE user_id IN (SELECT user_id FROM user WHERE email = 'test_unit@unr.edu');
DELETE FROM user WHERE email = 'test_unit@unr.edu';

-- Create a test standard user
INSERT INTO user (username, email, password_hash, region, external_login)
VALUES ('test_unit_user', 'test_unit@unr.edu', 'permanent_hash', 'NV', 0);

-- Call the otp_requested procedure
CALL otp_requested('test_unit@unr.edu', 'hashed_otp_123456');

-- Check if the procedure correctly updated the database state
SELECT 
    is_otp AS 'Is OTP Flag Active', 
    password_hash AS 'New Password Hash',
    (SELECT COUNT(*) FROM user_otp_attempt WHERE user_id = u.user_id) AS 'Log Entry Created'
FROM user u
WHERE email = 'test_unit@unr.edu';