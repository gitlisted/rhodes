
1. обьект может иметь специальный атрибут, который означает что будет сгенерирован код для инстанциирования обьекта по строковому айди
2. также метод может быть помечен как ФЭКТОРИ - это означает что метод возвращает строку или массив строк с айди обьектов которые будут инстанциированы в Руби обьекты или в Джаваскрипт обьекты по айди.
3. методы могут иметь атрибуты
call_in_thread - код метода должен быть вызван в отдельном треде (созданном специально для вызова этого метода)
call_in_ui_thread - код метода должен быть вызван из UI треда
4. также любой метод может быть вызван с заданием коллбека в параметрах (необязательный предпоследний параметр - строка) значит надо в любом методе опистаь это или вообще задекларировать что это для всех всегда - вопрос как передавать колбек явно когда его нужно сохранять (например для регулярных вызовов потом). Если задан колбек то нет возврата результата вообще а результат вернется в колбеке когда модуль сделать сетРезалт в МетодРезульт обьекте передаваемом в метод.

ВАЖНО - мы не можем просто передать колбек - метод должен учитывать это, что если есть колбек, то мы не моем сразу туда сетать результат так как будет дедлок с руби тредом.
Значит либо мы должны при заданном колбеке взводить по дефолту call_in_thread (если не заданы call_in_thread или call_in_ui_thread)
или мы должны дать это на откуп девлеопера - мол при явной передаче колбека нельзя его сразу дергать - ЭТО ПЛОХО !
На самом деле у Жени сейчас сделано так - если не в ЮАЙ треде то дергается в отдельном треде всегда !
Не понятно как делать возврат сразу - у нас значит должен быть доп атрибут синхронный и асинхронный у метода !
Сейчас работает так - если есть колбек, то значит дергаем в отдельном треде, если доп указано что в ЮАй то дергаем в ЮАй.

5. тип обьекта модет иметь спец атрибут - автогенерация дефаульта. 
Это означает что будет добавлен специальный атрибут default - который есть инстанс типа обьекта. Соотв. добавляется поддержка дефаульт айди для инстанциации. также добавляются все методы типа в виде статических методов типа - которые есть вызов аналогичный методов дефайльт обьекта.

