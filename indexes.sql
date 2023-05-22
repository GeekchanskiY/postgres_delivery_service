create index if not exists idx_order_time on orders(accept_time);
 
create index if not exists idx_user_role on users (role_id);
 
create index if not exists idx_product_name on products(product_name);
 
create index if not exists idx_order_state on orders (state_id);