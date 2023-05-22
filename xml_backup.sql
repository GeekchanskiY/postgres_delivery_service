CREATE OR REPLACE FUNCTION export_database(FILE_PATH TEXT)
RETURNS VOID AS
$$
DECLARE
  XML_DATA XML;
BEGIN
  SELECT XMLELEMENT(NAME "USERS", XMLAGG(XMLELEMENT(NAME "USER", 
    XMLFOREST(user_name, user_password, salt, role_id)))) INTO XML_DATA FROM users;

  XML_DATA := '<?xml version="1.0" encoding="UTF-8"?>' || XML_DATA::TEXT;

  PERFORM pg_catalog.PG_FILE_WRITE(FILE_PATH::TEXT, XML_DATA::TEXT);
END;
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION import_xml(FILE_PATH TEXT)
RETURNS TABLE (
  user_name varchar(255),
  user_password varchar(255),
  salt varchar(255),
  role_id INT
) AS $$
DECLARE
    XML_DATA XML;
    USER_DATA RECORD;
BEGIN
 DROP TABLE IF EXISTS TEMP_USERS;
    CREATE TEMP TABLE TEMP_USERS (
    user_name varchar(255),
	user_password varchar(255),
	salt varchar(255),
	role_id INT
    );
    
    XML_DATA := XMLPARSE(DOCUMENT CONVERT_FROM(PG_READ_BINARY_FILE(FILE_PATH), 'UTF8'));
    
    FOR USER_DATA IN SELECT * FROM XMLTABLE('/USERS/USER' PASSING XML_DATA columns
        user_name varchar(255) path 'user_name',
	    user_password varchar(255) path 'user_password',
	    salt varchar(255) path 'salt',
	    role INT path 'role_id'
    ) LOOP
        INSERT INTO TEMP_USERS ( user_name, user_password, salt, role_id)
        VALUES (
            USER_DATA.user_name,
            USER_DATA.user_password,
            USER_DATA.salt,
            USER_DATA.role_id
        );
    END LOOP;

    RETURN QUERY SELECT * FROM TEMP_USERS;
END;
$$ LANGUAGE PLPGSQL;


-- select export_database('/var/lib/postgresql/data/database.xml');