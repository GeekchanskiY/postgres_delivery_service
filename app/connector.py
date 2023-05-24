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
        elif e_text == 'Crypto does not exists!' or \
                e_text == 'Token does not exists!' or \
                e_text == 'News does not exists!':
            raise exc.DoesNotExistsException(e_text)
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
    ''' Crypto master with crypto manage priveleges and methods '''

    rolename = 'crypto_master'

    def __init__(self, user, password):
        super().__init__(user, password)

    def create_crypro(self, user_id, jwt, name, symbol, image_filename, price, volume, market_cap, transactions):
        # read image to bytea
        with open(f'/home/geek/repos/pg_course_project/app/images/{image_filename}', 'rb') as f:
            image = f.read().hex()
        res = self._exec(
            f"select create_crypto({user_id}, '{jwt}', '{name}', '{symbol}', '{image}', {price}, {volume}, {market_cap}, "
            f"{transactions})"
        )
        return res

    def create_crypto_shot(self, user_id, jwt, name, time, price, cap, volume, transactions):
        res = self._exec(
            f"select create_crypto_shot('{user_id}', '{jwt}', '{name}', '{time}', {price}, {cap}, {volume}, {transactions})"
        )
        return res

    def select_cryptos_by_page(self, user_id, jwt, page, per_page):
        res = self._exec_select(
            f"select get_all_crypto_by_page({user_id}, '{jwt}', {page}, {per_page})"
        )
        return res

    def select_crypto_comments(self, user_id, jwt, crypto_name):
        res = self._exec_select(
            f"select get_all_crypto_comments({user_id}, '{jwt}', '{crypto_name}')"
        )
        return res

    def select_crypto_month_stats(self, user_id, jwt, crypto_name):
        res = self._exec(
            f"select get_crypto_month_stats({user_id}, '{jwt}', '{crypto_name}')"
        )
        return res

    def delete_crypto(self, user_id, jwt, name):
        res = self._exec(f"select delete_crypto({user_id}, '{jwt}', '{name}')")
        return res

    def search_crypto(self, user_id, jwt, pattern):
        res = self._exec_select(f"select search_crypto({user_id}, '{jwt}', '{pattern}')")
        return res


if __name__ == '__main__':
    admin = CustomPostgresConnector('postgres', 'postgres')
    admin.create_user("Dimka", "DimkaP4S$W0RD", "superuser")
    print(admin._exec('SELECT * FROM USERS'))
    admin.login_user("Dimka", "DimkaP4S$W0RD")
    print(admin._exec('select * FROM auth_tokens'))
    print(admin._get_my_id())
    admin.delete_user("Dimka", "DimkaP4S$W0RD")
    user = UserMasterConnector('user_master', 'DummyP4S$W0RD')
