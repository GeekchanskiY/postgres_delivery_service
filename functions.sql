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

CREATE OR replace FUNCTION create_restaurant(
	publisher_id int,
	jwt varchar(255),
	new_name varchar(255),
	new_adress varchar(255),
	new_contact bytea
	
) returns varchar(255) SECURITY definer language plpgsql as $$
declare
	is_allowed bool;
begin
	select check_user_access(publisher_id, jwt, 'superuser') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	
	insert into restaurants(restaurant_name, adress, contact)
	values (new_name, new_adress, new_contact);
	return new_name;
end;
$$;

CREATE OR replace FUNCTION delete_restaurant(
	publisher_id int,
	jwt varchar(255),
	old_restaurant_name varchar(255)
	
) returns void SECURITY DEFINER language plpgsql as $$
declare
	is_allowed bool;
	old_restaurant_id int;
begin
	select check_user_access(publisher_id, jwt, 'superuser') into is_allowed;
	if (is_allowed = false)
	then
		
		raise exception 'Not allowed!';
	end if;

	select restaurant_id from restaurants where restaurant_name = old_restaurant_name into old_restaurant_id;
	if (old_restaurant_id is null)
	then
		raise exception 'restaurant does not exists!';
	end if;
	
	delete from restaurants where restaurant_id = old_restaurant_id;
	
	return;
end;
$$;

-- drop function create_product(int4, varchar, varchar, int4, text, varchar, varchar);

CREATE OR replace FUNCTION create_product(
	publisher_id int,
	jwt varchar(255),
	new_name varchar(255),
	new_price int,
	new_description text,
	new_restaurant_name varchar(255),
	new_category varchar(255)
) returns varchar(255) SECURITY definer language plpgsql as $$
declare
	is_allowed bool;
	new_r_id int;
	new_cat_id int;
begin
	select check_user_access(publisher_id, jwt, 'superuser') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	select restaurant_id from restaurants where restaurant_name = new_restaurant_name
	into new_r_id;
	if (new_r_id is null)
	then
		raise exception 'Restaurant does not exists!';
	end if;

	select category_id from category where category_name = new_category into new_cat_id;
	if (new_cat_id is null)
	then
		insert into category(category_name) values (new_category);
	end if;
	select category_id from category where category_name = new_category into new_cat_id;
	
	insert into products(product_name, price, description, restaurant_id, category_id)
	values (new_name, new_price, new_description, new_r_id, new_cat_id);
	return new_name;
end;
$$;

CREATE OR replace FUNCTION delete_product(
	publisher_id int,
	jwt varchar(255),
	old_product_name varchar(255)
	
) returns void SECURITY DEFINER language plpgsql as $$
declare
	is_allowed bool;
	old_product_id int;
begin
	select check_user_access(publisher_id, jwt, 'superuser') into is_allowed;
	if (is_allowed = false)
	then
		
		raise exception 'Not allowed!';
	end if;

	select product_id from products where product_name = old_product_name into old_product_id;
	if (old_product_id is null)
	then
		raise exception 'product does not exists!';
	end if;
	
	delete from products where product_id = old_product_id;
	
	return;
end;
$$;

--drop function create_order;
CREATE OR replace FUNCTION create_order(
	publisher_id int,
	jwt varchar(255),
	new_customer_name varchar(255),
	new_accept_time varchar(255)
	
) returns varchar(255) SECURITY definer language plpgsql as $$
declare
	is_allowed bool;
	new_c_id int;
	new_s_id int;
	new_d_id int;

	atime timestamp;

	new_c_role varchar(255);
	new_d_role varchar(255);
begin
	select check_user_access(publisher_id, jwt, 'superuser') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	select state_id from order_states where state_name = 'basket'
	into new_s_id;
	if (new_s_id is null)
	then
		raise exception 'State does not exists!';
	end if;

	select c.user_id, cr.role_name from users as c join user_role as cr on cr.role_id = c.role_id
	where c.user_name = new_customer_name
	into new_c_id, new_c_role;
	if (new_c_id is null)
	then
		raise exception 'User does not exists!';
	end if;
	--if (new_c_role != 'delivery')
	--then
	--	raise exception 'incorrect customer role!';
	--end if;

	
	
	insert into orders(customer_id, accept_time, state_id)
	values (new_c_id, new_accept_time::timestamp, new_s_id);
	return 'created';
end;
$$;

--insert into order_states(state_name) values ('ready'), ('not ready');
--select * from order_states;
--delete from order_states;
-- select create_order(6, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6IlZpa2EiLCJleHBpcmVzX2luIjoiMjAyMy0wNS0yNCAxNjo0NDoyMyJ9.4fRu1CTXeRmiBjv4SrkkWlJFpeFZiiQhNVlrdkeVhEM', 'Vika', 'Delivery', '2022-09-21 13:50', 'not ready');

CREATE OR replace FUNCTION delete_order(
	publisher_id int,
	jwt varchar(255),
	old_order_id varchar(255)
	
) returns void SECURITY DEFINER language plpgsql as $$
declare
	is_allowed bool;
	zold_order_id int;
begin
	select check_user_access(publisher_id, jwt, 'superuser') into is_allowed;
	if (is_allowed = false)
	then
		
		raise exception 'Not allowed!';
	end if;

	select order_id from orders where order_id = old_order_id into zold_order_id;
	if (zold_order_id is null)
	then
		raise exception 'order does not exists!';
	end if;
	
	delete from orders where order_id = zold_order_id;
	
	return;
end;
$$;


CREATE OR replace FUNCTION add_product_to_order(
	publisher_id int,
	jwt varchar(255),
	new_product varchar(255),
	
	new_order_id int,
	new_amount int
	
) returns varchar(255) SECURITY definer language plpgsql as $$
declare
	is_allowed bool;
	new_p_id int;
	new_o_id int;
begin
	select check_user_access(publisher_id, jwt, 'user') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	select product_id from products where product_name = new_product
	into new_p_id;
	if (new_p_id is null)
	then
		raise exception 'product does not exists!';
	end if;
	select o.order_id from orders as o where o.order_id = new_order_id
	into new_o_id;
	if (new_o_id is null)
	then
		raise exception 'order does not exists!';
	end if;
	
	insert into order_product(order_id, product_id, amount)
	values (new_o_id, new_p_id, new_amount);
	return 'added';
end;
$$;

CREATE OR replace FUNCTION remove_product_to_order(
	publisher_id int,
	jwt varchar(255),
	new_product varchar(255),
	
	new_order_id varchar(255)
	
) returns varchar(255) SECURITY definer language plpgsql as $$
declare
	is_allowed bool;
	new_p_id int;
	new_o_id int;
begin
	select check_user_access(publisher_id, jwt, 'user') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	select product_id from products where product_name = new_product_name
	into new_p_id;
	if (new_p_id is null)
	then
		raise exception 'product does not exists!';
	end if;
	select order_id from orders where order_name = new_order_name
	into new_o_id;
	if (new_o_id is null)
	then
		raise exception 'order does not exists!';
	end if;
	
	delete from order_product where order_id = new_o_id and product_id = new_p_id;
	return 'removed';
end;
$$;

create or replace function get_my_id(
	jwt varchar(255)
) returns INTEGER SECURITY DEFINER language plpgsql as $$
declare
	uid INT;
begin
	select user_id from auth_tokens where auth_token = jwt into uid;
	if (uid is null)
	then
		raise exception 'Token does not exists!';
	end if;
	return uid;
end;
$$;

--drop function update_user_name(int4, varchar);
CREATE OR REPLACE FUNCTION update_user_name(nuser_id INT, jwt varchar(255), nnew_name VARCHAR)
RETURNS VOID AS $$
declare 
	res varchar(255);
	is_allowed bool;
	
begin
	-- Check if user does not exists
	select user_name from users where user_name = new_user_name into res;
	if (res is  null) 
	then 
		raise exception 'User dont exists!';
	end if;

select check_user_access(nuser_id, jwt, 'user') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;

    UPDATE users
    SET user_name = nnew_name
    WHERE user_id = nuser_id;
END;
$$ LANGUAGE plpgsql;


---SELECT update_user_name(8, 'Dkfl,');
select * from users;

CREATE OR REPLACE FUNCTION update_user_password(nuser_id INT, jwt varchar(255), nuser_password VARCHAR)
RETURNS VOID AS $$
declare 
	u_salt varchar(255);
	res varchar(255);
	new_hashed_password varchar(255);
begin
	-- Check if user does not exists
	select user_name from users where user_name = new_user_name into res;
	if (res is null) 
	then 
		raise exception 'User dont exists!';
	end if;

select check_user_access(nuser_id, jwt, 'user') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	select salt from users where user_id = nuser_id into u_salt;
	select crypt(nuser_password, salt) into new_hashed_password;
    UPDATE users
    SET user_password = new_hashed_password
    WHERE user_id = nuser_id;
END;
$$ LANGUAGE plpgsql;


