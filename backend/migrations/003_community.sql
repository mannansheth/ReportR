-- Additive community schema. Run node scripts/migrate-community.js to also bootstrap deterministic metadata for existing reports.

CREATE TABLE IF NOT EXISTS report_community (Rid VARCHAR(20) PRIMARY KEY, categoryKey VARCHAR(255) NOT NULL, baselinePriority INT NOT NULL, createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP);

CREATE TABLE IF NOT EXISTS report_confirmations (Rid VARCHAR(20) NOT NULL, userID INT NOT NULL, latitude DOUBLE NOT NULL, longitude DOUBLE NOT NULL, accuracy DOUBLE NOT NULL, locatedAt DATETIME NOT NULL, createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(Rid,userID));

CREATE TABLE IF NOT EXISTS report_resolution_votes (Rid VARCHAR(20) NOT NULL, userID INT NOT NULL, note VARCHAR(2000) NOT NULL DEFAULT '', imageURL VARCHAR(1000) NULL, photoVerified TINYINT NOT NULL DEFAULT 0, evidenceState VARCHAR(30) NOT NULL DEFAULT 'none', weight INT NOT NULL, latitude DOUBLE NOT NULL, longitude DOUBLE NOT NULL, accuracy DOUBLE NOT NULL, locatedAt DATETIME NOT NULL, createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(Rid,userID));
