-- Learn hub: make deletes work.
--
-- Root cause of "cannot delete unit / lesson":
--   * learn_units.unlock_after is a self-referencing FK created with the default
--     NO ACTION behaviour, so deleting a unit that another unit "unlocks after"
--     is refused (learn_units_unlock_after_fkey).
--   * The unit -> lesson and lesson -> step FKs were likewise NO ACTION, so a unit
--     with lessons, or a lesson with steps, could not be removed.
--
-- Fix:
--   * unlock_after  -> ON DELETE SET NULL  (dropping a prerequisite unit just
--     turns its dependants back into "open from start", never blocks the delete).
--   * unit_id        -> ON DELETE CASCADE  (deleting a unit removes its lessons).
--   * lesson_id      -> ON DELETE CASCADE  (deleting a lesson removes its steps).
--
-- The DO block drops whatever the existing single-column FK is named first, so
-- this is safe regardless of the constraint names in your instance (and avoids
-- leaving a second, stricter FK in place that would keep blocking deletes).

do $$
declare
  r record;
begin
  for r in
    select con.conname, con.conrelid::regclass::text as tbl
    from pg_constraint con
    join pg_attribute a
      on a.attrelid = con.conrelid and a.attnum = any (con.conkey)
    where con.contype = 'f'
      and (
        (con.conrelid = 'public.learn_units'::regclass   and a.attname = 'unlock_after') or
        (con.conrelid = 'public.learn_lessons'::regclass and a.attname = 'unit_id')     or
        (con.conrelid = 'public.learn_steps'::regclass   and a.attname = 'lesson_id')
      )
  loop
    execute format('alter table %s drop constraint %I', r.tbl, r.conname);
  end loop;
end $$;

alter table public.learn_units
  add constraint learn_units_unlock_after_fkey
  foreign key (unlock_after) references public.learn_units (id)
  on delete set null;

alter table public.learn_lessons
  add constraint learn_lessons_unit_id_fkey
  foreign key (unit_id) references public.learn_units (id)
  on delete cascade;

alter table public.learn_steps
  add constraint learn_steps_lesson_id_fkey
  foreign key (lesson_id) references public.learn_lessons (id)
  on delete cascade;
