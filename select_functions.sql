create or replace function get_order_stats(
	publisher_id int,
	jwt varchar(255),
	norder_id int
) returns table(
	order_id int,
	product_name varchar(255),
	product_amount int,
	restaurant_name varchar(255),
	customer_id int,
	delivery_guy int
	
) SECURITY definer language plpgsql
as $$
declare 
	is_allowed bool;
	
begin 
	select check_user_access(publisher_id, jwt, 'user') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	
	return query select * from order_details where order_id = norder_id;
end;
$$;

create or replace function get_order_info(
	publisher_id int,
	jwt varchar(255),
	norder_id int
) returns table(
	order_id int,
	customer_id int,
	delivery_guy int,
	accept_time timestamp,
	state_id int) SECURITY definer language plpgsql
as $$
declare 
	is_allowed bool;
begin 
	select check_user_access(publisher_id, jwt, 'user') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	return query select * from orders as o where o.order_id = norder_id;
end; 
$$;

-- drop function search_product(int4, varchar, varchar) ;
create or replace function search_product(
	publisher_id int,
	jwt varchar(255),
	search_query varchar(255)
) returns table(
	product_id int,
	product_name varchar(255),
	price int,
	description text,
	category_id int,
	restaurant_id int) SECURITY definer language plpgsql
as $$
declare 
	is_allowed bool;
	search_pattern text := '%' || search_query || '%';
begin 
	select check_user_access(publisher_id, jwt, 'user') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	return query select * from products as p where p.product_name like search_pattern limit 10;
end; 
$$;

create or replace function get_my_orders(
	publisher_id int,
	jwt varchar(255)
) returns table (order_id int)  SECURITY definer language plpgsql
as $$
declare 
	is_allowed bool;
begin
	select check_user_access(publisher_id, jwt, 'user') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	return query select o.order_id from orders as o where o.customer_id = publisher_id;
end;
$$;
-- delete from restaurants;

create or replace function get_order_details(
	publisher_id int,
	jwt varchar(255),
	norder_id int
) returns table (
	order_id_i int,
	o_product_name varchar(255),
	o_product_amount int,
	o_product_restaurant_name varchar(255),
	o_customer_id int,
	o_delivery_guy int
) SECURITY definer language plpgsql
as $$
declare 
	is_allowed bool;
begin
	select check_user_access(publisher_id, jwt, 'user') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	return query select * from order_details as o where o.order_id = norder_id;
end;
$$;


CREATE OR REPLACE FUNCTION count_users()
RETURNS INT AS $$
DECLARE
    user_count INT;
BEGIN
    SELECT COUNT(*) INTO user_count FROM users;
    RETURN user_count;
END;
$$ LANGUAGE plpgsql;

--select  count_users();

CREATE OR REPLACE FUNCTION calculate_total_cost()
RETURNS NUMERIC AS $$
DECLARE
    total_cost NUMERIC := 0;
    
BEGIN
    select  SUM(p.price * op.amount) into total_cost
    from orders as o
    inner join order_product as op on o.order_id = op.order_id
	inner join products as p on p.product_id = op.product_id;
   
    RETURN total_cost;
END;
$$ LANGUAGE plpgsql;


--select calculate_total_cost();

CREATE OR REPLACE FUNCTION get_order_count()
RETURNS INTEGER AS $$
DECLARE
    order_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO order_count
    FROM orders;
   
    RETURN order_count;
END;
$$ LANGUAGE plpgsql;

--select get_order_count();

create or replace function calculate_order_stats(
	uid int,
	jwt varchar(255),
	norder_id int
) returns varchar(255) security definer language plpgsql as $$
declare 
	is_allowed bool;
	order_summary_price int;
begin
	select check_user_access(uid, jwt, 'user') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	select sum(p.price * op.amount) from orders as o
	inner join order_product as op on o.order_id = op.order_id
	inner join products as p on p.product_id = op.product_id
	where o.order_id = norder_id into order_summary_price;
	return 'Summary price:' || order_summary_price::varchar;
end;
$$;

create or replace function select_available_orders(
	uid int,
	jwt varchar(255)
) returns table (zorder_adress varchar(255), zcustomer_name varchar(255), zorder_id int)
 security definer language plpgsql as $$
declare 
	is_allowed bool;
	order_available int;
begin
	select check_user_access(uid, jwt, 'delivery_guy') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	select state_id from order_states where state_name = 'in progress' into order_available;
	return query select cc.region, cc.user_name, o.order_id from orders as o
	inner join users as cc on cc.user_id = o.customer_id
	where o.state_id = order_available;
end;
$$;

create or replace function confirm_order(
	uid int,
	jwt varchar(255),
	zorder_id int
) returns varchar(255) security definer language plpgsql as $$
declare 
	is_allowed bool;
	order_available int;
begin
	select check_user_access(uid, jwt, 'user') into is_allowed;
	if (is_allowed = false)
	then
		raise exception 'Not allowed!';
	end if;
	if (uid != (select customer_id from orders where order_id = zorder_id))
	then 
		raise exception 'Not your order!';
	end if;
	select state_id from order_states where state_name = 'in progress' into order_available;
	update orders set state_id = order_available where order_id = zorder_id;
	return 'Success!';
end;
$$;

-- select state_id from order_states where state_name = 'in progress';

select * from products;
---select * from users;
---select calculate_order_stats(6,'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6IlZpa2EiLCJleHBpcmVzX2luIjoiMjAyMy0wNS0zMCAxMzo0Mzo0MyJ9.nbSB2NII0Ry-g_rwIpUZsd_NnBYFPOgaX2aTDfVU6lU',250);



