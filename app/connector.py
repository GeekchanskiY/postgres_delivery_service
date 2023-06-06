''' PGSQL connection logic here '''

from datetime import datetime, timedelta

from sqlalchemy import create_engine, text
from sqlalchemy.exc import DBAPIError
# import psycopg2
# from sqlalchemy.schema import Sequence

from JWT_logic import JWTHolder

from redis_connector import RedisConnector

from exceptions import CustomExceptions as exc


class CustomConnector:
    ''' Base Connector class with all priveleges. Use only for tests! '''

    rolename = 'postgres'

    jwt: JWTHolder

    redis: RedisConnector

    uid: int

    def __init__(self, user, password):
        # self.conn = psycopg2.connect(
        #     host='0.0.0.0',
        #     database='postgres',
        #     user=user,
        #     password=password
        # )
        self.engine = create_engine(
            f'postgresql+psycopg2://{user}:{password}@0.0.0.0/postgres'
        )
        self.redis = RedisConnector()
        self._check_role()
        # self.cur = self.conn.cursor()

    def _check_role(self):
        if self._get_role() != self.rolename:
            raise exc.InvalidPrivelegeExceprion(f'You do not have \'{self.rolename}\' role!')

    def _get_role(self) -> str | None:
        rolname = self._exec(
            'SELECT rolname '
            'FROM pg_roles '
            'WHERE rolname = current_user;'
        )
        if rolname is not None:
            return str(rolname[0][0])

    def _exec(self, query_str: str) -> list | None:
        # self.cur.execute(query_str)
        # res = self.cur.fetchall()
        with self.engine.connect() as conn:
            try:
                result = conn.execute(text(query_str))
                conn.execute(text('COMMIT'))
                return list(result.all())
            except DBAPIError as e:
                self._handle_exception(str(e.orig))
            except Exception:
                return None

    def _exec_select(self, query_str: str):
        # self.cur.execute(query_str)
        # res = self.cur.fetchall()
        with self.engine.connect() as conn:
            try:
                result = conn.execute(text(query_str))
                return result.fetchall()
            except DBAPIError as e:
                self._handle_exception(str(e.orig))
            except Exception:
                return None

    def _exec_no_transaction(self, query_str: str) -> list | None:
        with self.engine.connect() as conn:
            try:
                result = conn.execute(text(query_str))
                # conn.execute(text('COMMIT'))
                return list(result.all())
            except DBAPIError as e:
                self._handle_exception(str(e.orig))
            except Exception:
                return None

    def _get_exception_text(self, orig: str) -> str:
        return orig.split('\n')[0]

    def _handle_exception(self, e_text: str) -> None:

        e_text = self._get_exception_text(e_text)

        # TODO: add additional parameters
        # to make Exception more informative

        if e_text == "Password is weak!":
            raise exc.WeakPasswordException(e_text)
        elif e_text == 'User already exists!':
            raise exc.UserAlreadyExistsException(e_text)
        elif e_text == 'User does not exists!':
            raise exc.UserDoesNotExistsException(e_text)
        elif e_text == 'Not allowed!':
            raise exc.InvalidPrivelegeExceprion(e_text)
        else:
            raise Exception('New_exception: ' + e_text)


class CustomPostgresConnector(CustomConnector):
    ''' Postgres connector with all permissions and methods. Use Only for tests! '''

    rolename = 'postgres'

    available_roles = ['superuser', 'user', 'news_author', 'admin']

    # token_live_time = timedelta(minutes=30)

    def __init__(self, user, password):
        super().__init__(user, password)

    def create_user(self, username, password, role) -> str:
        res = self._exec(
            f"select create_user('{username}', '{password}', '{role}')"
        )
        return str(res)

    def delete_user(self, username, password) -> str:
        res = self._exec(
            f"select delete_user('{username}', '{password}')"
        )
        return str(res)

    def login_user(self, username, password) -> str:
        self.jwt = JWTHolder(username)
        token = self.jwt.get_jwt()
        exp_in = self.jwt.expires_in

        res = self._exec(
            f"select login_user('{username}', '{password}', '{token}', '{exp_in}' )"
        )
        self.redis.set_jwt(username, token, exp_in)
        return str(res)

    def _get_my_id(self):
        token = self.jwt.get_jwt()

        res = self._exec(
            f"select get_my_id('{token}')"
        )
        if res is not None:
            res = res[0][0]
            self.uid = res

        return res


class UserMasterConnector(CustomConnector):
    ''' User master with users manage priveleges and methods '''

    rolename = 'user_master'

    jwt: JWTHolder

    def __init__(self, user, password):
        super().__init__(user, password)

    def create_user(self, username, password, role) -> str:
        if self.jwt is None:
            raise exc.InvalidPrivelegeExceprion('You should auth first!')
        res = self._exec(
            f"select create_user('{username}', '{password}', '{role}')"
        )
        return str(res)

    def create_standard_user(self, username, password) -> str:
        res = self._exec(
            f"select create_standard_user('{username}', '{password}')"
        )
        return str(res)

    def delete_user(self, username, password) -> str:
        res = self._exec(
            f"select delete_user('{username}', '{password}')"
        )
        return str(res)

    def login_user(self, username, password) -> str:
        self.jwt = JWTHolder(username)
        token = self.jwt.get_jwt()
        exp_in = self.jwt.expires_in

        if self.redis.get_jwt(username) is not None:
            old_token = self.redis.get_jwt(username)

            res = self._exec(f"select update_login_user('{username}', '{password}', '{token}', '{exp_in}', '{old_token}')")
            self.redis.set_jwt(username, token, exp_in)
            return str(res)

        res = self._exec(
            f"select login_user('{username}', '{password}', '{token}', '{exp_in}' )"
        )
        self.redis.set_jwt(username, token, exp_in)
        self._get_my_id()
        return str(res)

    def _get_my_id(self):
        token = self.jwt.get_jwt()

        res = self._exec(
            f"select get_my_id('{token}')"
        )
        if res is not None:
            res = res[0][0]
            self.uid = res

        return res

    def get_my_orders(self):
        token = self.jwt.get_jwt()
        uid = self._get_my_id()
        res = self._exec(
            f"select get_my_likes({uid}, '{token}')"
        )
        return res


class OrderConnector(CustomConnector):
    ''' Order master with crypto manage priveleges and methods '''

    rolename = 'order_master'

    def __init__(self, user, password):
        super().__init__(user, password)

    def create_order(self, user_id, jwt, customer_name, delivery_guy, accept_time, state_name):
        # read image to bytea
        # with open(f'/home/geek/repos/pg_course_project/app/images/{image_filename}', 'rb') as f:
        #    image = f.read().hex()
        res = self._exec(
            f"select create_order({user_id}, '{jwt}', '{customer_name}', '{delivery_guy}', '{accept_time}', '{state_name}')"
        )
        return res

    def create_restaurant(self, user_id, jwt, name, adress, contact):
        res = self._exec(
            f"select create_restaurant('{user_id}', '{jwt}', '{name}', '{adress}', '{contact}')"
        )
        return res

    def create_product(self, user_id, jwt, name, price, desc, restaurant_name):
        res = self._exec(
            f"select create_product('{user_id}', '{jwt}', '{name}', {price}, '{desc}', '{restaurant_name}')"
        )
        return res

    def create_category(self, user_id, jwt, name):
        res = self._exec(
            f"select create_category({user_id}, '{jwt}', '{name}')"

        )
        return res

    def add_product_to_order(self, user_id, jwt, product, order_id, amount):
        res = self._exec(
            f"select add_product_to_order({user_id}, '{jwt}', '{product}', {order_id}, {amount})"
        )
        return res

    def get_my_orders(self, user_id, jwt):
        res = self._exec(
            f"select get_my_orders('{user_id}', '{jwt}')"
        )
        return res

    def get_order_info(self, user_id, jwt, order_id):
        res = self._exec(
            f"select get_order_info({user_id}, '{jwt}', {order_id})"
        )
        return res

    def get_order_details(self, user_id, jwt, order_id):
        res = self._exec_select(
            f"select get_order_details({user_id}, '{jwt}', {order_id})"
        )
        return res


if __name__ == '__main__':
    admin = CustomPostgresConnector('postgres', 'postgres')
    # admin.create_user("Vika", "VikaP4S$W0RD", "superuser")

    # Проверка чтобы работали исключения (wrong role)
    try:
        admin.create_user("Delivery", "DeliveryP4S$W0RD", 'delivery_guy')
    except Exception as e:
        print(str(e))

    # admin.create_user("Delivery", "DeliveryP4S$W0RD", 'delivery_guy')

    # print(admin._exec('SELECT * FROM USERS'))
    admin.login_user("Vika", "VikaP4S$W0RD")
    # print(admin._exec('select * FROM auth_tokens'))
    uid = admin._get_my_id()
    jwt = admin.jwt.get_jwt()

    print(f"My id is: {uid}")
    print(f"JWT: {jwt}")

    admin._exec('delete from restaurants')
    admin._exec('delete from products')
    admin._exec('delete from orders')

    input("press any key to start creation")

    user_manager = UserMasterConnector('user_master', 'DummyP4S$W0RD')
    order_manager = OrderConnector('order_master', 'DummyP4S$W0RD')

    delivery_manager = UserMasterConnector('user_master', 'DummyP4S$W0RD')
    delivery_manager.login_user('Delivery', "DeliveryP4S$W0RD")
    duid = delivery_manager._get_my_id()
    djwt = delivery_manager.jwt.get_jwt()

    for i in range(100):
        order_manager.create_restaurant(uid, jwt, f'Balkon{i}', 'Путейская 68', 'lalala')
    import random
    product_ids = []
    for i in range(100):
        for z in range(100):
            new_product_name = f'Product{i}{z}{random.randint(1,100)}'
            product_ids.append(new_product_name)
            try:
                order_manager.create_product(uid, jwt, new_product_name,
                                             (i * z) + 1, 'product', f'Balkon{i}')
            except Exception as e:
                print(str(e))
    print('1000 lines inserted')

    for i in range(5):
        try:
            order_manager.create_order(uid, jwt, 'Vika', 'Delivery', '12-12-12 13:00', 'not ready')
            print('Order created!')
        except Exception as e:
            print(str(e))
    orders = order_manager.get_my_orders(uid, jwt)
    print(f"My orders: {orders}")
    my_order_ints = []
    if orders is not None:
        for o in orders:
            my_order_ints.append(int(str(o).split('(')[1].split(',')[0]))
    for order_id in my_order_ints:

        products = set(random.choices(product_ids, k=10))
        for p in products:

            order_manager.add_product_to_order(uid, jwt, p, order_id, random.randint(1, 100))
            print("product added")

        stats = order_manager.get_order_info(uid, jwt, order_id)
        print("ORDER STATS")
        print(stats)
        print("ORDER DETAILS")
        details = order_manager.get_order_details(uid, jwt, order_id)
        if details is not None:
            for d in details:
                print(d)

    while True:
        print('Выбор действия:')
        print('1 - Создать ресторан')
        print('2 - Создать продукт')
        print('3 - Создать заказ')
        print('4 - Добавить продукт в заказ')
        print('5 - Убрать продукт из заказа')
        print('6 - просмотреть мои заказы')
        print('7 - изменить статус заказа')
        print('8 - Добавить доставщика')
        print('9 - Найти продукты')
        print('10 - Цена заказа')
        # print('11 - Статистика')
        print('0: выйти из программы')
        x = input('-->')
        x = int(x)

        if x == 1:
            b = input('Введите название ресторана \n -->')
            a = input('Введите адрес ресторана \n --> ')
            c = input('Введите контакты ресторана \n -->')
            try:
                order_manager.create_restaurant(uid, jwt, b, a, c)
                print('Ресторан добавлен')
            except Exception as e:
                print(str(e))
        elif x == 2:
            b = input('Введите название ресторана \n -->')
            a = input('Введите название продукта \n -->')
            d = input('Введите описание продукта \n -->')
            p = input('Введите цену продукта \n -->')
            try:
                order_manager.create_product(uid, jwt, a, p, d, b)
            except Exception as e:
                print(str(e))
        elif x == 3:
            d = input('Введите имя доставщика \n -->')
            p = input('Введите желаемое время выдачи заказа прим. 2012-12-12 13:00 \n -->')
            try:
                order_manager.create_order(uid, jwt, 'Vika', d, p, 'not ready')
            except Exception as e:
                print(e)

        elif x == 4:
            p = input('Введите название продукта \n -->')
            a = input('Введите коллиичество товара \n -->')
            u = input('Введите id заказа \n -->')
            try:
                admin._exec(
                    f"select add_product_to_order({uid}, '{jwt}', '{p}', {u}, {a})"
                )
                print('Товар добавлен')
            except Exception as e:
                print(e)
        elif x == 5:
            p = input('Введите название продукта \n -->')
            u = input('Введите id заказа \n -->')
            try:
                admin._exec(
                    f"select remove_product_to_order({uid}, '{jwt}', '{p}', {u})"
                )
                print('Товар удалён')
            except Exception as e:
                print(e)

        elif x == 6:
            try:
                orders = order_manager.get_my_orders(uid, jwt)
                print(f"My orders: {orders}")
                my_order_ints = []
                if orders is not None:
                    for o in orders:
                        my_order_ints.append(int(str(o).split('(')[1].split(',')[0]))
                for order_id in my_order_ints:
                    stats = order_manager.get_order_info(uid, jwt, order_id)
                    print("ORDER STATS")
                    print(stats)
                    print("ORDER DETAILS")
                    details = order_manager.get_order_details(uid, jwt, order_id)
                    if details is not None:
                        for d in details:
                            print(d)
            except Exception as e:
                print(str(e))
            print('Первая цифра - id')
        elif x == 7:
            asd = input('Введите id заказа \n -->')
            try:
                admin._exec(f'UPDATE ORDERS SET state_id = 5 where order_id = {asd}')
                admin._exec('Commit')
            except Exception as e:
                print(str(e))
        elif x == 8:
            u = input('Введите имя доставщика: \n -->')
            try:
                admin.create_user(u, "DeliveryP4S$W0RD", 'delivery_guy')
            except Exception as e:
                print(str(e))
        elif x == 9:
            q = input('Введите поисковый запрос \n -->')

            try:
                print(order_manager._exec_select(f"select search_product({uid}, '{jwt}', '{q}')"))
            except Exception as e:
                print(str(e))
        elif x == 10:
            q = input('Введите id заказа \n -->')
            try:
                print(order_manager._exec(f"select calculate_order_stats({uid}, '{jwt}', {q})"))
            except Exception as e:
                print(str(e))
        else:
            break


    # order_manager.create_restaurant('')

    # order_manager.login_user("Vika", "VikaP4S$W0RD")
    # user_manager.login_user("Vika", 'VikaP4S$W0RD')

    # admin.delete_user("Vika", "VikaP4S$W0RD")
    # user = UserMasterConnector('user_master', 'DummyP4S$W0RD')
    # input("press any key to delete data...")
    # admin._exec('delete from restaurants')
    # admin._exec('delete from products')
    print('Everything dropped')
