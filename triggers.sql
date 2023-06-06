create or replace function raise_when_too_many_orders()
returns trigger as
$$
declare 
order_nums int;
depending_delivery_id int;
begin
depending_delivery_id := new.delivery_guy;
select count(*) from orders where delivery_guy = depending_delivery_id into order_nums;
if (order_nums > 5) 
then
    raise exception 'Too many orders for this delivery guy!';
end if;

return new;
end;
$$ language plpgsql;

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'raise_when_too_many_orders_trigger'
    ) THEN
        create trigger raise_when_too_many_orders_trigger
after insert on orders for each row
execute function raise_when_too_many_orders();
    END IF;
END;
$$;




CREATE OR REPLACE FUNCTION check_order_status()
RETURNS TRIGGER AS $$
declare 
nstate_id int;
rstate_id int;
BEGIN
     select state_id from orders WHERE orders.order_id = NEW.order_id into nstate_id;
     select state_id from order_states where state_name = 'done' into rstate_id;
     if( nstate_id = rstate_id )
     THEN
        RAISE EXCEPTION 'Невозможно добавить продукт в заказ со статусом "done"';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'check_order_status'
    ) THEN
        create trigger check_order_status
before insert on order_product for each row
execute function check_order_status();
    END IF;
END;
$$;

-- drop trigger check_order_status on orders;

--select * from orders;
--select * from order_states;
--select * from products;
insert into order_product(order_id, product_id, amount) values (226, 264818, 30);

