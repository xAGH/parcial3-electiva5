CREATE DATABASE IF NOT EXISTS taskdb;

CREATE TABLE taskdb.tasks (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255),
    description TEXT,
    status VARCHAR(255),
    created_at DATETIME NOT NULL DEFAULT NOW(),
    updated_at DATETIME,
    deleted_at DATETIME
);

CREATE USER IF NOT EXISTS 'taskgetuser'@'%' IDENTIFIED BY 'taskgetpassword';
CREATE USER IF NOT EXISTS 'taskpostuser'@'%' IDENTIFIED BY 'taskpostpassword';
CREATE USER IF NOT EXISTS 'taskpatchuser'@'%' IDENTIFIED BY 'taskpatchpassword';
CREATE USER IF NOT EXISTS 'taskdeleteuser'@'%' IDENTIFIED BY 'taskdeletepassword';

GRANT SELECT ON taskdb.tasks TO 'taskgetuser'@'%';
GRANT INSERT ON taskdb.tasks TO 'taskpostuser'@'%';
GRANT SELECT, UPDATE ON taskdb.tasks TO 'taskpatchuser';
GRANT SELECT, UPDATE, DELETE ON taskdb.tasks TO 'taskdeleteuser';

FLUSH PRIVILEGES;
