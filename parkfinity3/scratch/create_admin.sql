DO $$
DECLARE
  new_user_id uuid := gen_random_uuid();
BEGIN
  -- 1. Insert into auth.users
  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, 
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data, 
    created_at, updated_at
  ) VALUES (
    new_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 
    'admin@parkfinity.com', crypt('admin123', gen_salt('bf')), 
    now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Admin User","role":"Admin"}', 
    now(), now()
  );

  -- 2. Insert into auth.identities
  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, provider_id
  ) VALUES (
    gen_random_uuid(), new_user_id, format('{"sub":"%s","email":"admin@parkfinity.com","email_verified":false,"phone_verified":false}', new_user_id)::jsonb, 
    'email', now(), now(), now(), new_user_id::text
  );
END $$;
