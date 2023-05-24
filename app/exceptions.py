class CustomExceptions:
    class InvalidPrivelegeExceprion(Exception):
        def __init__(self, message: str) -> None:
            self.message = message
            super().__init__(self.message)

    class RoleDoesNotExists(Exception):
        def __init__(self, message: str) -> None:
            self.message = message
            super().__init__(self.message)

    class UserAlreadyExistsException(Exception):
        def __init__(self, message: str) -> None:
            self.message = message
            super().__init__(self.message)

    class UserDoesNotExistsException(Exception):
        def __init__(self, message: str) -> None:
            self.message = message
            super().__init__(message)

    class WeakPasswordException(Exception):
        def __init__(self, message: str) -> None:
            self.message = message
            super().__init__(message)

    class DoesNotExistsException(Exception):
        def __init__(self, message: str) -> None:
            self.message = message
            super().__init__(message)
