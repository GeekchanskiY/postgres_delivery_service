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