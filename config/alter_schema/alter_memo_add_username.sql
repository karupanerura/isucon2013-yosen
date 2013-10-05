ALTER TABLE memos DROP COLUMN username;
ALTER TABLE memos ADD COLUMN `username` varchar(255) NOT NULL AFTER user; -- FOR CACHE
UPDATE memos SET username = (SELECT username FROM users WHERE id = memos.user);
