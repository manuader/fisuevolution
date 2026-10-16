-- requires: pg_net
-- pg_net no admite ALTER EXTENSION … SET SCHEMA: se baja y se vuelve a crear en `extensions`,
-- como pide el linter. Sus tablas y funciones viven siempre en el esquema `net`, así que el cron
-- de remoderate (que llama a net.http_post) no cambia; sólo se pierde la cola de pedidos en vuelo,
-- que el cron vuelve a mandar a los 15 minutos.
create schema if not exists extensions;
drop extension if exists pg_net;
create extension pg_net with schema extensions;
