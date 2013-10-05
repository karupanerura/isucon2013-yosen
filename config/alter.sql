
DROP TABLE IF EXISTS memos_new;
CREATE TABLE memos_new LIKE memos;
ALTER TABLE memos_new
    ADD COLUMN `username` varchar(20) NOT NULL AFTER user, -- FOR CACHE
    DROP COLUMN `updated_at`,
    ADD INDEX is_private_created_at (is_private, created_at),
    ADD INDEX user_created_at (is_private, created_at);
INSERT INTO memos_new
    (id, user, username, content, is_private, created_at, updated_at)
    SELECT memos.id, memos.user, users.username, memos.content, memos.is_private, memos.created_at, memos.updated_at FROM memos INNER JOIN users ON memos.user = users.id;
RENAME TABLE memos TO memos_old, memos_new TO memos;
DROP TABLE memos_old;

