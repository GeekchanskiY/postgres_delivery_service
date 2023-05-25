insert into user_role(role_name) values
('superuser'), ('user'), ('delivery_guy');

-- delete from user_role;

create role order_manager LOGIN;
create role user_manager LOGIN;

grant insert on users to user_manager;
grant execute on function create_user to user_manager;
grant execute on function create_standard_user to user_manager;
grant execute on function login_user to user_manager;
grant execute on function get_my_id to user_manager;


-- grant execute on function create_standard_user to order_manager;


do
$$
begin
  if not exists (select * from pg_user where usename = 'user_master') then
     create user user_master with password 'DummyP4S$W0RD';
     grant user_manager to user_master;
  end if;
end
$$;


do
$$
begin
  if not exists (select * from pg_user where usename = 'order_master') then
     create user order_master with password 'DummyP4S$W0RD';
     grant order_manager to order_master;
  end if;
end
$$;