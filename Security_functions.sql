-- Security function to get user role and auth by provided jwt
create or replace function check_user_access(
	u_id INT,
	u_jwt VARCHAR(255),
	expected_role varchar(255)
) returns bool language plpgsql as $$
declare 
	real_id INT;
	real_role VARCHAR(255);
	expected_role_id INT;
	real_jwt VARCHAR(255);
	real_expires_in timestamp;
begin 
	select user_id, expires_in, auth_token from auth_tokens 
	where u_jwt = auth_token
	into real_id, real_expires_in, real_jwt;
	if (real_jwt is null)
	then
		raise exception 'No JWT found';
	end if;
	
	if (real_expires_in < current_timestamp)
	then
		return false;
	end if;
	
	-- select real role name
	select user_role.role_name from users 
	inner join user_role on users.role_id = user_role.role_id 
	where users.user_id = real_id into real_role;
	
	if (real_role = 'superuser')
	then
		return true;
	end if;
	
	if (real_role = expected_role)
	then
		return true;
	end if;
	
	return false;
end;
$$;

-- Function to check password strength
create or replace function check_password_strength(password varchar(255))
returns boolean
as $$
declare
    num_uppercase int;
    num_lowercase int;
    num_digits int;
    num_special int;
    repeated_chars int;
    i int;
begin
    if length(password) < 8 then
        return false;
    end if;
    
    num_uppercase := 0;
    num_lowercase := 0;
    num_digits := 0;
    num_special := 0;
    repeated_chars := 0;
    
    for i in 1..length(password) loop
        if substring(password from i for 1) ~ '[A-Z]' then
            num_uppercase := num_uppercase + 1;
        elsif substring(password from i for 1) ~ '[a-z]' then
            num_lowercase := num_lowercase + 1;
        elsif substring(password from i for 1) ~ '[0-9]' then
            num_digits := num_digits + 1;
        else
            num_special := num_special + 1;
        end if;
        
        if i < length(password) and substring(password from i for 1) = substring(password from i+1 for 1) then
            repeated_chars := repeated_chars + 1;
        end if;
    end loop;
    
    -- or repeated chars > 0
    if num_uppercase = 0 or num_lowercase = 0 or num_digits = 0 or num_special = 0 then
        return false;
    end if;
    
    return true;
end;
$$ language plpgsql;
