create or replace function create_user(
	new_user_name varchar(255),
	new_user_password varchar(255),
	new_user_role_name varchar(255)
) returns varchar(255) SECURITY DEFINER language plpgsql as $$
declare 
	new_user_role_id INT;
	res varchar(255);
	bres bool;
	salt varchar(255);
	hashed_password varchar(255);
begin
	
	-- Check if user does not exists
	select user_name from users where user_name = new_user_name into res;
	if (res is not null) 
	then 
		raise exception 'User already exists!';
	end if;
	
	-- Check if role exists
	select role_id from user_role where role_name = new_user_role_name into new_user_role_id;
	if (new_user_role_id is null)
	then
		raise exception 'Incorrect role!';
	end if;
	
	-- Check if password is strong
	select check_password_strength(new_user_password) into bres;
	if (bres = false)
	then 
		raise exception 'Password is weak!';
	end if;
	
	-- generate salt and crypt password for user
	select gen_salt('bf') into salt;
	select crypt(new_user_password, salt) into hashed_password;

	insert into users(user_name, user_password, salt, role_id) values
	(new_user_name, hashed_password, salt, new_user_role_id);
	return new_user_name;
end;
$$;

create or replace function delete_user(
	old_user_name varchar(255),
	old_user_password varchar(255)
) returns varchar(255) SECURITY DEFINER language plpgsql as $$
declare 
	uid INT;
	login varchar(255);
	user_salt varchar(255);
	hashed_password varchar(255);
	user_pass varchar(255);
begin 
	select user_id, user_name, salt, user_password from users where user_name = old_user_name
	into uid, login, user_salt, hashed_password;
	if (login is null) 
	then
		raise exception 'User does not exists!';
	end if;

	select crypt(old_user_password, user_salt) into user_pass;

	if (user_pass = hashed_password)
	then
		delete from users where user_id = uid;
	else
		raise exception 'Incorrect password!';
	end if;
	return login;
end;
$$;

create or replace function create_standard_user(
	new_user_name varchar(255),
	new_user_password varchar(255)
)returns varchar(255) SECURITY definer language plpgsql as $$
declare 
	new_user_role_id INT;
	res varchar(255);
	bres bool;
	salt varchar(255);
	hashed_password varchar(255);
begin
	
	-- Check if user does not exists
	select user_name from users where user_name = new_user_name into res;
	if (res is not null) 
	then 
		raise exception 'User already exists!';
	end if;
	
	-- Select standart
	select role_id from user_role where role_name = 'user' into new_user_role_id;
	
	
	-- Check if password is strong
	select check_password_strength(new_user_password) into bres;
	if (bres = false)
	then 
		raise exception 'Password is weak!';
	end if;
	
	-- generate salt and crypt password for user
	select gen_salt('bf') into salt;
	select crypt(new_user_password, salt) into hashed_password;

	insert into users(user_name, user_password, salt, role_id) values
	(new_user_name, hashed_password, salt, new_user_role_id);
	
	return new_user_name;
end;
$$;

create or replace function login_user(
	login varchar(255),
	pass varchar(255),
	jwt varchar(255),
	uexp_in varchar(255)
) returns varchar(255) SECURITY DEFINER language plpgsql as $$
declare
	user_salt varchar(255);
	hashed_password varchar(255);
	
	uid int;
	user_token varchar(255);
	user_pass varchar(255);

	old_jwt varchar(255);
begin
	select user_id, user_name, salt, user_password from users where user_name = login
	into uid, login, user_salt, hashed_password;
	if (login is null) 
	then
		raise exception 'User does not exists!';
	end if;

	select crypt(pass, user_salt) into user_pass;

	if (user_pass != hashed_password)
	then
		-- Setting token to database
		-- data is being validated on server, so there is a potential block
		-- TODO: change this function and check token here
		raise exception 'Incorrect password!';
		--insert into auth_tokens(user_id, expires_in, auth_token) values
		--(uid, uexp_in::timestamp, jwt);
		--return 'success';
		
	end if;
	if ((select 1 from auth_tokens where user_id = uid) is not null)
	then
		select auth_token from auth_tokens
		where user_id = uid into old_jwt;
		select update_login_user(
			login,
			pass,
			jwt,
			uexp_in,
			old_jwt
		) into old_jwt;
		return 'Update user login success';
	end if;
	insert into auth_tokens(user_id, expires_in, auth_token) values
	(uid, uexp_in::timestamp, jwt);
	return 'success';
end;
$$;

create or replace function update_login_user(
	login varchar(255),
	pass varchar(255),
	jwt varchar(255),
	uexp_in varchar(255),
	old_jwt varchar(255)
) returns varchar(255) SECURITY DEFINER language plpgsql as $$
declare
	user_salt varchar(255);
	hashed_password varchar(255);
	
	old_token varchar(255);

	uid int;
	token_uid int;

	user_token varchar(255);
	user_pass varchar(255);
begin
	select user_id, user_name, salt, user_password from users where user_name = login
	into uid, login, user_salt, hashed_password;
	if (login is null) 
	then
		raise exception 'User does not exists!';
	end if;
	
	select auth_token from auth_tokens
	where auth_token = old_jwt
	into old_token;
	if (old_token is null)
	then
		raise exception 'Old auth does not exists!';
	end if;

	select crypt(pass, user_salt) into user_pass;

	if (user_pass = hashed_password)
	then
		-- Setting token to database
		-- data is being validated on server, so there is a potential block
		-- TODO: change this function and check token here
		UPDATE auth_tokens set expires_in = uexp_in::timestamp,
		auth_token = jwt where user_id = uid;
		return 'success';
	else
		raise exception 'Incorrect password!';
	end if;
end;
$$;




