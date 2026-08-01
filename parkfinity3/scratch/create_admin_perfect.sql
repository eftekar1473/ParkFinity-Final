DO $$
DECLARE
  new_user_id uuid := gen_random_uuid();
BEGIN
  -- 1. Insert into auth.users
  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, 
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data, 
    created_at, updated_at, is_anonymous, is_sso_user, email_change_confirm_status
  ) VALUES (
    new_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 
    'admin@parkfinity.com', crypt('adminpassword123', gen_salt('bf')), 
    now(), '{"provider":"email","providers":["email"]}', 
    format('{"email":"admin@parkfinity.com","email_verified":true,"full_name":"Admin User","role":"Admin","sub":"%s"}', new_user_id)::jsonb, 
    now(), now(), false, false, 0
  );

  -- 2. Insert into auth.identities
  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, provider_id
  ) VALUES (
    gen_random_uuid(), new_user_id, 
    format('{"sub":"%s","email":"admin@parkfinity.com","email_verified":true,"phone_verified":false,"full_name":"Admin User"}', new_user_id)::jsonb, 
    'email', now(), now(), now(), new_user_id::text
  );
END $$;
