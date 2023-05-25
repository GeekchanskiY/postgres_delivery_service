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
	return query select * from orders where order_id = norder_id;
end; 
$$;

create or replace function search_product(
	publisher_id int,
	jwt varchar(255),
	search_query varchar(255)
) returns table(
	product_id int,
	product_name varchar(255),
	price int,
	description text,
	
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
	return query select * from products where product_name like search_pattern limit 10;
end; 
$$;

-- delete from restaurants;





