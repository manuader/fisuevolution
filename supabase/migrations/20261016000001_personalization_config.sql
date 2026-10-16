-- La config remota de la personalización (2.1, E15 F1, contrato C3). Sale APAGADA: el interruptor
-- settings.personalization_enabled se siembra en false y la config en una versión 0 vacía.
-- La app la pide con POST /rest/v1/rpc/personalization_config: con el interruptor apagado recibe null y juega la
-- base. anon no lee settings directo (RLS sin políticas): sólo esta función, que devuelve una única fila.
insert into public.settings (key, value) values
  ('personalization_enabled', 'false'::jsonb),
  ('personalization_config', '{"version": 0, "sections": {}}'::jsonb);

-- Sólo un true explícito prende; sin la fila, o con cualquier otro valor, devuelve null. La config sale sólo si
-- es un objeto y entra en el tope del cuerpo de C3 (64 KB): si no, null, y la app se queda en la base.
create function public.personalization_config() returns jsonb
language sql stable security definer set search_path = '' as $$
  select case
    when coalesce((select value = 'true'::jsonb from public.settings where key = 'personalization_enabled'), false)
    then (select value from public.settings
          where key = 'personalization_config'
            and jsonb_typeof(value) = 'object'
            and octet_length(value::text) <= 65536)
  end
$$;

revoke execute on function public.personalization_config() from public, anon, authenticated;
grant execute on function public.personalization_config() to anon, service_role;
