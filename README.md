ctrl+alt+t -- открыть терминал
ctrl+shift+t -- открыть терминал в новой вкладке
ctrl+shift+<- or -> -- поменять вкладку в терминале

cd -- перейти в папку
cd .. -- на папку вверх
ls -- посмотреть содержимое папки
nvim -- открыть IDE 
<F2> -- открыть проводник

дальше там как мышкой можно

в папке repos/postgres_delivery_service/app:
source env/bin/activate -- включить виртуальное окружение
(там все библиотеки для работы, а именно:
    psycopg2 - для подключения к бд
    SQLAlchemy - для ОРМ
    redis - подключение к redis
)

потом python connector.py -- автоматически создаёт всю парашу и тд,
там уже на выбор можно тыкать всё.

На случай если ноутбук перезагрузился перед самим КП и выдаётся ошибка:
в папке repos/postgres_delivery_service:
sudo docker-compose stop redis
sudo docker-compose start redis
