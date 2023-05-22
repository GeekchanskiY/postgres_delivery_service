create table if not exists USER_ROLE (
	role_id serial primary key,
	role_name varchar(50) unique not null
) tablespace TS_USER;

create table if not exists USERS (
	user_id serial primary key,
	user_name varchar(255) not null unique,
	user_password varchar(255) not null,
	salt varchar(255) not null,
	role_id INT,
	constraint FK_ROLE foreign key(role_id) references USER_ROLE(role_id) on delete cascade
) tablespace TS_USER;

create table if not exists AUTH_TOKENS (
	user_id INT unique not null,
	expires_in TIMESTAMP default current_timestamp not null,
	auth_token varchar(255) unique not null,
	
	constraint FK_USER foreign key(user_id) references USERS(user_id) on delete cascade
) tablespace TS_USER;

create table if not exists order_states (
	state_id serial primary key,
	state_name varchar(255) not null
) tablespace TS_USER;

create table if not exists restaurants (
	restaurant_id serial primary key,
	restaurant_name varchar(255) not null,
	adress varchar(255),
	contact varchar(255)
) tablespace TS_ORDER;

create table if not exists products (
	product_id serial primary key,
	product_name varchar(255) not null,
	price int not null,
	description text,
	
	restaurant_id int not null,
	
	constraint FK_RESTAURANT foreign key(restaurant_id) references restaurants(restaurant_id) on delete cascade
	
) tablespace TS_ORDER;

create table if not exists orders(
	order_id serial primary key,
	customer_id int not null,
	delivery_guy int not null,
	accept_time timestamp not null,
	state_id int not null,
	
	constraint FK_customer foreign key(customer_id) references users(user_id) on delete cascade,
	constraint FK_delivery foreign key(delivery_guy) references users(user_id) on delete cascade,
	constraint FK_state foreign key(state_id) references order_states(state_id) on delete cascade
	
	
) tablespace TS_ORDER;

create table if not exists order_product(
	order_id int not null,
	product_id int not null
) tablespace TS_ORDER;




