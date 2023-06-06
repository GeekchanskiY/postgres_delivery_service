import tkinter as tk
from tkinter import messagebox

#
#  CLASSES
#

class Product:
    def __init__(self, name, price, description):
        self.name = name
        self.price = price
        self.description = description

    def __str__(self):
        return f"Название: {self.name}, Цена: {self.price}, Описание: {self.description}"

class Restaurant:
    def __init__(self, name, adress, contact):
        self.name = name
        self.adress = adress
        self.contact = contact
    
    def __str__(self):
        return f"Название: {self.name} Адрес: {self.adress} Контакт: {self.contact}"

class User:
    def __init__(self, name, role):
        self.name = name
        self.role = role
    
    def __str__(self) -> str:
        return f"Имя: {self.name} Роль: {self.role}"


class Order:
    ''' Order class '''
    def __init__(self, customer, delivery, accept_time, state, products) -> None:
        ''' products: [{product: Product, amount: int}] '''
        self.customer = customer
        self.delivery = delivery
        self.accept_time = accept_time
        self.state = state
        self.products = products


class App(tk.Frame):
    user: User | None = None
    def __init__(self, master=None):
        super().__init__(master)
        self.master = master
        self.master.title("ВкусноКушать")

        self.create_widgets()

    def create_widgets(self):
        self.label_username = tk.Label(self.master, text="Имя пользователя:")
        self.label_username.pack()
        self.entry_username = tk.Entry(self.master)
        self.entry_username.pack()

        self.label_password = tk.Label(self.master, text="Пароль:")
        self.label_password.pack()
        self.entry_password = tk.Entry(self.master, show="*")
        self.entry_password.pack()

        self.btn_login = tk.Button(self.master, text="Войти", command=self.login)
        self.btn_login.pack()

    def login(self):
        username = self.entry_username.get()
        password = self.entry_password.get()

        if username == "admin" and password == "password":
            messagebox.showinfo("Успешный вход", "Добро пожаловать, " + username + "!")
            self.open_product_window()
        else:
            messagebox.showerror("Ошибка входа", "Неверное имя пользователя или пароль.")

    def open_product_window(self):
        self.master.withdraw()

        product_window = tk.Toplevel(self.master)
        product_window.title("Список товаров")

        label_products = tk.Label(product_window, text="Список товаров:")
        label_products.pack()

        listbox_products = tk.Listbox(product_window)
        listbox_products.pack()

        products = ["Товар 1", "Товар 2", "Товар 3"]
        for product in products:
            listbox_products.insert(tk.END, product)


def main():
    root = tk.Tk()
    app = App(master=root)
    app.mainloop()


if __name__ == "__main__":
    main()
