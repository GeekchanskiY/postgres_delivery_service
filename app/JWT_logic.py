''' JWT encode, decode and storing '''

from datetime import datetime, timedelta
import jwt


class JWTHolder:
    current_token: str | None = None
    algorithm = 'HS256'
    secret = 'secret'
    username: str
    expires_in: str

    lifetime: timedelta = timedelta(minutes=30)

    def __init__(self, username: str,
                 algorithm: str | None = None,
                 secret: str | None = None):
        self.username = username
        # self.uid = uid

        if algorithm is not None:
            self.algorithm = algorithm
        if secret is not None:
            self.secret = secret

    def _create_jwt(self, expires_in: datetime) -> str:
        self.expires_in = expires_in.strftime("%Y-%m-%d %H:%M:%S")
        self.current_token = jwt.encode(
            {
                # 'uid': self.uid,
                'username': self.username,
                'expires_in': str(self.expires_in)
            },
            self.secret,
            algorithm=self.algorithm
        )
        return self.current_token

    def get_jwt(self) -> str:
        if self.current_token is None:
            new_jwt = self._create_jwt(datetime.now() + self.lifetime)
            return new_jwt
        else:
            return self.current_token

    def decode_jwt(self) -> str:
        if self.current_token is None:
            return 'err'
        return str(
            jwt.decode(
                self.current_token,
                self.secret,
                algorithms=[self.algorithm]
            )
        )

    def _check_lifetime(self) -> bool:
        expires_in = datetime.strptime(self.expires_in, "%Y-%m-%d %H:%M:%S")

        if expires_in > datetime.now():
            return False

        return True


if __name__ == "__main__":
    holder = JWTHolder('admin')
    holder._create_jwt(datetime.now() + timedelta(minutes=30))
    print(holder.current_token)
    print(holder.decode_jwt())
