-- Keep extension-owned functions and operators out of the exposed API schema.
alter extension pg_trgm set schema extensions;
