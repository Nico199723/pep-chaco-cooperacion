-- PEP Chaco +20 | Instalación inicial, PostgreSQL 15+ / Supabase.
-- Ejecutar una vez en un proyecto nuevo. No contiene usuarios ni claves.
begin;
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, anon;

create table public.perfiles (
 id uuid primary key references auth.users(id) on delete cascade,
 rol text not null default 'lector' check (rol in ('admin','editor','lector')),
 nombre text not null default '', area text not null default '',
 creado_en timestamptz not null default now()
);
create table private.sesiones (
 id uuid primary key, usuario uuid not null references auth.users(id) on delete cascade,
 actividad timestamptz not null default now(), revocada boolean not null default false
);
alter table private.sesiones enable row level security;
revoke all on private.sesiones from public,anon,authenticated;
create function private.rol() returns text language sql stable security definer set search_path='' as $$
 select rol from public.perfiles where id=auth.uid()
$$;
create function private.area() returns text language sql stable security definer set search_path='' as $$
 select area from public.perfiles where id=auth.uid()
$$;
create function private.sesion_activa() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.sesiones where id=nullif(auth.jwt()->>'session_id','')::uuid
 and usuario=auth.uid() and not revocada and actividad>now()-interval '30 minutes')
$$;
create function private.admin() returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(private.rol()='admin' and private.sesion_activa(),false)
$$;
create function private.editor() returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(private.rol()='editor' and private.sesion_activa(),false)
$$;
create function public.actividad_sesion() returns void language plpgsql security definer set search_path='' as $$
declare s uuid:=nullif(auth.jwt()->>'session_id','')::uuid; v private.sesiones;
begin
 if auth.uid() is null or s is null then raise exception 'Iniciá sesión'; end if;
 perform pg_advisory_xact_lock(hashtextextended(s::text,0));
 select * into v from private.sesiones where id=s for update;
 if found then
  if v.usuario<>auth.uid() or v.revocada or v.actividad<=now()-interval '30 minutes' then raise exception 'Sesión vencida. Volvé a ingresar.'; end if;
  update private.sesiones set actividad=now() where id=s;
 else
  if to_timestamp((auth.jwt()->>'iat')::double precision)<now()-interval '2 minutes' then raise exception 'Volvé a iniciar sesión'; end if;
  insert into private.sesiones(id,usuario) values(s,auth.uid());
 end if;
end $$;
create function public.cerrar_sesion() returns void language sql security definer set search_path='' as $$
 update private.sesiones set revocada=true where id=nullif(auth.jwt()->>'session_id','')::uuid and usuario=auth.uid()
$$;
create function private.crear_perfil() returns trigger language plpgsql security definer set search_path='' as $$
begin
 -- El rol NO se toma de user_metadata, que el usuario puede modificar.
 insert into public.perfiles(id,nombre) values(new.id,coalesce(new.raw_user_meta_data->>'nombre',''));
 return new;
end $$;
create trigger crear_perfil after insert on auth.users for each row execute function private.crear_perfil();
insert into public.perfiles(id) select id from auth.users on conflict do nothing;

create table public.oportunidades (
 id uuid primary key default gen_random_uuid(), codigo text not null check(length(trim(codigo))>0),
 nombre text not null check(length(trim(nombre))>0), organismo text not null check(length(trim(organismo))>0),
 ambito text not null check(ambito in ('Internacional','Nacional','Provincial')),
 apertura date, cierre date,
 estado text not null check(estado in ('Abierta','Próxima','Permanente','Cerrada')),
 monto_min numeric check(monto_min>=0), monto_max numeric check(monto_max>=0), moneda text not null default 'No informado',
 tipo text not null check(tipo in ('No reembolsable','Reembolsable','Mixto','Asistencia técnica','Premio')),
 resumen text not null default 'No informado' check(length(resumen)<=900),
 link text check(link is null or link ~ '^https?://[^[:space:]]+$'),
 area_canalizadora text not null check(length(trim(area_canalizadora))>0), area_apoyo text not null default 'No informado',
 sector_destinatario text[] not null default '{}', subsector text[] not null default '{}',
 eje_principal text not null check(eje_principal in ('Chaco + Fuerte','Chaco + Humanizado','Chaco con + Identidad','Chaco + Ágil','Sin eje / a revisar')),
 ejes_secundarios text[] not null default '{}' check(cardinality(ejes_secundarios)<=2),
 requisitos_contrapartida text not null default 'No informado', fecha_relevamiento date,
 confianza text not null check(confianza in ('Alto','Medio','Bajo')),
 origen text not null default 'Descubierta' check(origen in ('Semilla','Descubierta')),
 fuente_encontrada text not null default 'No informado', fuente_primaria_verificada text not null default 'No informado',
 motivo_relevancia text not null default 'No informado', puntaje_relevancia integer not null default 1 check(puntaje_relevancia between 1 and 5),
 posible_duplicado_de uuid references public.oportunidades(id), senales_alerta text not null default '',
 estado_revision text not null default 'pendiente' check(estado_revision in ('pendiente','aprobada','rechazada','archivada')),
 motivo_rechazo text, creado_por uuid references auth.users(id) on delete set null,
 aprobado_por uuid references auth.users(id) on delete set null, fecha_aprobacion timestamptz,
 creado_en timestamptz not null default now(), actualizado_en timestamptz not null default now(), version integer not null default 1,
 check(apertura is null or cierre is null or apertura<=cierre),
 check(monto_min is null or monto_max is null or monto_min<=monto_max),
 check(estado_revision<>'rechazada' or length(trim(motivo_rechazo))>0),
 check(ejes_secundarios <@ array['Chaco + Fuerte','Chaco + Humanizado','Chaco con + Identidad','Chaco + Ágil']),
 check(not eje_principal=any(ejes_secundarios)),
 check(sector_destinatario <@ array['Gubernamental','No gubernamental'])
);
create function private.url_normalizada(t text) returns text language sql immutable set search_path='' as $$
 select nullif(regexp_replace(lower(split_part(trim(t),'#',1)),'/+$',''),'')
$$;
create function private.texto_normalizado(t text) returns text language sql immutable set search_path='' as $$
 select regexp_replace(translate(lower(trim(t)),'áéíóúüñ','aeiouun'),'[[:space:]]+',' ','g')
$$;
create unique index aprobada_codigo on public.oportunidades(lower(codigo)) where estado_revision='aprobada';
create unique index aprobada_link on public.oportunidades(private.url_normalizada(link)) where estado_revision='aprobada' and link is not null;
create unique index aprobada_nombre_organismo on public.oportunidades(private.texto_normalizado(nombre),private.texto_normalizado(organismo)) where estado_revision='aprobada';
create index cola_revision on public.oportunidades(estado_revision,puntaje_relevancia desc,cierre);
create index propuestas_autor on public.oportunidades(creado_por,area_canalizadora);

create table public.fuentes (
 id uuid primary key default gen_random_uuid(), nombre text not null, url text not null unique check(url ~ '^https?://[^[:space:]]+$'),
 tipo text not null default 'No informado', ejes text[] not null default '{}',
 estado text not null default 'candidata' check(estado in ('semilla','candidata','aprobada','bloqueada')),
 motivo text not null default '', creado_por uuid references auth.users(id) on delete set null default auth.uid(),
 actualizado_en timestamptz not null default now(),
 check(estado<>'bloqueada' or length(trim(motivo))>0)
);
create table public.historial (
 id bigint generated always as identity primary key, tabla text not null, registro_id text not null,
 accion text not null, usuario uuid, fecha timestamptz not null default now(), antes jsonb, despues jsonb
);
create function private.auditar() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.historial(tabla,registro_id,accion,usuario,antes,despues)
 values(tg_table_name,coalesce(new.id,old.id)::text,tg_op,auth.uid(),case when tg_op<>'INSERT' then to_jsonb(old) end,case when tg_op<>'DELETE' then to_jsonb(new) end);
 return coalesce(new,old);
end $$;
create function private.validar_oportunidad() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
  new.estado_revision:='pendiente';new.motivo_rechazo:=null;new.aprobado_por:=null;new.fecha_aprobacion:=null;
  new.creado_por:=auth.uid();new.creado_en:=now();new.version:=1;
  select id into new.posible_duplicado_de from public.oportunidades o where
   lower(o.codigo)=lower(new.codigo) or (new.link is not null and private.url_normalizada(o.link)=private.url_normalizada(new.link)) or
   (private.texto_normalizado(o.nombre)=private.texto_normalizado(new.nombre) and private.texto_normalizado(o.organismo)=private.texto_normalizado(new.organismo))
   order by (estado_revision='aprobada') desc,creado_en desc limit 1;
 else
  if new.id<>old.id then raise exception 'El identificador es inmutable'; end if;
  new.creado_por:=old.creado_por;new.creado_en:=old.creado_en;new.version:=old.version+1;
  if not private.admin() and auth.uid() is not null then
   if new.estado_revision<>'pendiente' or old.estado_revision<>'pendiente' then raise exception 'Solo el administrador puede revisar';end if;
   new.aprobado_por:=null;new.fecha_aprobacion:=null;new.motivo_rechazo:=null;
   new.posible_duplicado_de:=old.posible_duplicado_de;
  elsif new.estado_revision='aprobada' then
   new.aprobado_por:=auth.uid();new.fecha_aprobacion:=now();new.motivo_rechazo:=null;
  else
   new.aprobado_por:=null;new.fecha_aprobacion:=null;
  end if;
 end if;
 if new.estado_revision='rechazada' and coalesce(length(trim(new.motivo_rechazo)),0)=0 then raise exception 'El motivo de rechazo es obligatorio';end if;
 if new.estado_revision='aprobada' and (new.link is null or new.fuente_primaria_verificada='No informado' or new.fecha_relevamiento is null) then
  raise exception 'Para aprobar, completá el link, la fuente primaria verificada y la fecha de relevamiento';end if;
 new.actualizado_en:=now();return new;
end $$;
create trigger validar_oportunidad before insert or update on public.oportunidades for each row execute function private.validar_oportunidad();
create function private.validar_perfil() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.id<>old.id then raise exception 'El usuario es inmutable';end if;
 perform pg_advisory_xact_lock(203020);
 if old.rol='admin' and new.rol<>'admin' and (select count(*) from public.perfiles where rol='admin')<2 then raise exception 'Debe quedar al menos un administrador';end if;
 return new;
end $$;
create trigger validar_perfil before update on public.perfiles for each row execute function private.validar_perfil();
create trigger historial_oportunidades after insert or update or delete on public.oportunidades for each row execute function private.auditar();
create trigger historial_fuentes after insert or update or delete on public.fuentes for each row execute function private.auditar();
create trigger historial_perfiles after insert or update or delete on public.perfiles for each row execute function private.auditar();

alter table public.perfiles enable row level security;
alter table public.oportunidades enable row level security;
alter table public.fuentes enable row level security;
alter table public.historial enable row level security;
revoke all on public.perfiles,public.oportunidades,public.fuentes,public.historial from anon,authenticated;
grant select,update on public.perfiles to authenticated;
grant select,insert,update on public.oportunidades to authenticated;
grant select,insert,update on public.fuentes to authenticated;
grant select on public.historial to authenticated;
create policy perfiles_lectura on public.perfiles for select to authenticated using(id=auth.uid() or private.admin());
create policy perfiles_admin on public.perfiles for update to authenticated using(private.admin()) with check(private.admin());
create policy oportunidades_lectura on public.oportunidades for select to anon,authenticated using(
 estado_revision='aprobada' or private.admin() or (private.editor() and creado_por=auth.uid() and area_canalizadora=private.area()));
create policy oportunidades_insertar on public.oportunidades for insert to authenticated with check(
 estado_revision='pendiente' and creado_por=auth.uid() and (private.admin() or (private.editor() and area_canalizadora=private.area())));
create policy oportunidades_editar on public.oportunidades for update to authenticated using(
 private.admin() or (private.editor() and creado_por=auth.uid() and area_canalizadora=private.area() and estado_revision='pendiente'))
 with check(private.admin() or (private.editor() and creado_por=auth.uid() and area_canalizadora=private.area() and estado_revision='pendiente'));
create policy fuentes_lectura on public.fuentes for select to authenticated using(private.admin());
create policy fuentes_insertar on public.fuentes for insert to authenticated with check(private.admin());
create policy fuentes_editar on public.fuentes for update to authenticated using(private.admin()) with check(private.admin());
create policy historial_admin on public.historial for select to authenticated using(private.admin());
-- El público accede solo a estos campos. La vista no evade RLS (security_invoker).
grant select(id,codigo,nombre,organismo,ambito,apertura,cierre,estado,monto_min,monto_max,moneda,tipo,resumen,link,area_canalizadora,area_apoyo,sector_destinatario,subsector,eje_principal,ejes_secundarios,requisitos_contrapartida,fecha_relevamiento,confianza,estado_revision) on public.oportunidades to anon;
create view public.oportunidades_publicas with (security_invoker=true) as
 select id,codigo,nombre,organismo,ambito,apertura,cierre,
 case when cierre<(now() at time zone 'America/Argentina/Buenos_Aires')::date then 'Cerrada'
 when estado='Cerrada' then 'Cerrada'
 when apertura>(now() at time zone 'America/Argentina/Buenos_Aires')::date then 'Próxima'
 when estado='Próxima' and apertura<=(now() at time zone 'America/Argentina/Buenos_Aires')::date then 'Abierta' else estado end as estado,
 monto_min,monto_max,moneda,tipo,resumen,link,area_canalizadora,area_apoyo,sector_destinatario,subsector,eje_principal,ejes_secundarios,requisitos_contrapartida,fecha_relevamiento,confianza
 from public.oportunidades where estado_revision='aprobada';
grant select on public.oportunidades_publicas to anon,authenticated;

-- RPC de revisión: lote atómico y control de versión (evita pisar otra revisión).
create function public.revisar_lote(items jsonb, decision text, motivo text default null) returns integer
language plpgsql security invoker set search_path='' as $$
declare item jsonb;n integer:=0;
begin
 if not private.admin() then raise exception 'Administrador con sesión activa requerido';end if;
 if decision not in ('aprobada','rechazada','archivada') then raise exception 'Decisión inválida';end if;
 if jsonb_array_length(items) not between 1 and 25 then raise exception 'Seleccioná de 1 a 25 filas';end if;
 for item in select value from jsonb_array_elements(items) loop
  update public.oportunidades set estado_revision=decision,motivo_rechazo=case when decision='rechazada' then motivo else null end
  where id=(item->>'id')::uuid and version=(item->>'version')::integer and (estado_revision='pendiente' or decision='archivada');
  if not found then raise exception 'La propuesta cambió o ya fue revisada. Actualizá la cola.';end if;n:=n+1;
 end loop;return n;
end $$;

-- Importador: nunca aprueba. Duplicados pendientes se omiten; cambios de aprobadas
-- se conservan como una propuesta separada para fusión explícita.
create function public.importar_propuestas(filas jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare j jsonb;r public.oportunidades;d public.oportunidades;result jsonb:='[]';nuevo uuid;
begin
 if not private.admin() then raise exception 'Administrador con sesión activa requerido';end if;
 if jsonb_array_length(filas) not between 1 and 25 then raise exception 'Máximo 25 propuestas por corrida';end if;
 perform pg_advisory_xact_lock(203021);
 for j in select value from jsonb_array_elements(filas) loop
  r:=jsonb_populate_record(null::public.oportunidades,j);
  select * into d from public.oportunidades o where
   lower(o.codigo)=lower(r.codigo) or (r.link is not null and private.url_normalizada(o.link)=private.url_normalizada(r.link)) or
   (private.texto_normalizado(o.nombre)=private.texto_normalizado(r.nombre) and private.texto_normalizado(o.organismo)=private.texto_normalizado(r.organismo))
   order by (estado_revision='pendiente') desc,(estado_revision='rechazada') desc,creado_en desc limit 1;
  if found and (d.estado_revision='pendiente' or (d.estado_revision='rechazada' and coalesce(length(trim(j->>'cambio_sustancial')),0)<15)) then
   result:=result||jsonb_build_array(jsonb_build_object('codigo',r.codigo,'resultado','omitida','motivo','Duplicado pendiente o rechazo sin cambio sustancial','id',d.id));continue;
  end if;
  if d.estado_revision='rechazada' then r.senales_alerta:=concat_ws('; ',r.senales_alerta,'Rechazo anterior: '||d.motivo_rechazo,'Cambio sustancial declarado: '||(j->>'cambio_sustancial'));end if;
  insert into public.oportunidades(codigo,nombre,organismo,ambito,apertura,cierre,estado,monto_min,monto_max,moneda,tipo,resumen,link,area_canalizadora,area_apoyo,sector_destinatario,subsector,eje_principal,ejes_secundarios,requisitos_contrapartida,fecha_relevamiento,confianza,origen,fuente_encontrada,fuente_primaria_verificada,motivo_relevancia,puntaje_relevancia,senales_alerta) values(r.codigo,r.nombre,r.organismo,r.ambito,r.apertura,r.cierre,r.estado,r.monto_min,r.monto_max,r.moneda,r.tipo,r.resumen,r.link,r.area_canalizadora,r.area_apoyo,r.sector_destinatario,r.subsector,r.eje_principal,r.ejes_secundarios,r.requisitos_contrapartida,r.fecha_relevamiento,r.confianza,r.origen,r.fuente_encontrada,r.fuente_primaria_verificada,r.motivo_relevancia,r.puntaje_relevancia,r.senales_alerta) returning id into nuevo;
  result:=result||jsonb_build_array(jsonb_build_object('codigo',r.codigo,'resultado','pendiente','id',nuevo));
 end loop;return result;
end $$;

-- Fusión explícita: usa los datos de la propuesta y conserva la identidad del destino.
-- Ambas filas se bloquean en orden estable; el origen queda archivado.
create function public.fusionar_propuesta(origen_id uuid,destino_id uuid,version_origen integer,version_destino integer) returns void
language plpgsql security invoker set search_path='' as $$
declare s public.oportunidades;t public.oportunidades;
begin
 if not private.admin() then raise exception 'Administrador con sesión activa requerido';end if;
 if origen_id=destino_id then raise exception 'Origen y destino deben ser distintos';end if;
 perform id from public.oportunidades where id in (origen_id,destino_id) order by id for update;
 select * into s from public.oportunidades where id=origen_id;
 select * into t from public.oportunidades where id=destino_id;
 if s.id is null or t.id is null or s.estado_revision<>'pendiente' or s.version<>version_origen or t.version<>version_destino then raise exception 'Las filas cambiaron. Actualizá la cola.';end if;
 update public.oportunidades set estado_revision='archivada' where id=s.id;
 update public.oportunidades set nombre=s.nombre,organismo=s.organismo,ambito=s.ambito,apertura=s.apertura,cierre=s.cierre,estado=s.estado,monto_min=s.monto_min,monto_max=s.monto_max,moneda=s.moneda,tipo=s.tipo,resumen=s.resumen,link=s.link,area_canalizadora=s.area_canalizadora,area_apoyo=s.area_apoyo,sector_destinatario=s.sector_destinatario,subsector=s.subsector,eje_principal=s.eje_principal,ejes_secundarios=s.ejes_secundarios,requisitos_contrapartida=s.requisitos_contrapartida,fecha_relevamiento=s.fecha_relevamiento,confianza=s.confianza,origen=s.origen,fuente_encontrada=s.fuente_encontrada,fuente_primaria_verificada=s.fuente_primaria_verificada,motivo_relevancia=s.motivo_relevancia,puntaje_relevancia=s.puntaje_relevancia,senales_alerta=s.senales_alerta,estado_revision='aprobada',posible_duplicado_de=null,motivo_rechazo=null where id=t.id;
end $$;

-- Las funciones no heredan el permiso EXECUTE público predeterminado.
revoke all on all functions in schema private from public,anon,authenticated;
grant execute on function private.rol(),private.area(),private.sesion_activa(),private.admin(),private.editor(),private.url_normalizada(text),private.texto_normalizado(text) to anon,authenticated;
revoke all on function public.actividad_sesion(),public.cerrar_sesion(),public.revisar_lote(jsonb,text,text),public.importar_propuestas(jsonb),public.fusionar_propuesta(uuid,uuid,integer,integer) from public,anon;
grant execute on function public.actividad_sesion(),public.cerrar_sesion(),public.revisar_lote(jsonb,text,text),public.importar_propuestas(jsonb),public.fusionar_propuesta(uuid,uuid,integer,integer) to authenticated;
commit;
