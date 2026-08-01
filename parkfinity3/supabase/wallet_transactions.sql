-- Create transactions table
CREATE TYPE transaction_type AS ENUM ('deposit', 'booking_deduction', 'earning', 'withdrawal');

CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    amount DECIMAL(12, 2) NOT NULL,
    type transaction_type NOT NULL,
    status payment_status DEFAULT 'Completed',
    reference_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- RLS for transactions
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own transactions"
ON transactions FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Service role can insert transactions"
ON transactions FOR INSERT
WITH CHECK (true); -- We will rely on RPCs for inserts from client

-- RPC to add funds (used after successful SSLCommerz payment)
CREATE OR REPLACE FUNCTION add_funds(user_id_param UUID, amount_param DECIMAL, txn_id_param VARCHAR)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update wallet balance
    UPDATE profiles
    SET wallet_balance = wallet_balance + amount_param,
        updated_at = NOW()
    WHERE id = user_id_param;

    -- Insert transaction record
    INSERT INTO transactions (user_id, amount, type, status, reference_id)
    VALUES (user_id_param, amount_param, 'deposit', 'Completed', txn_id_param);
END;
$$;

-- RPC to deduct funds (used during booking checkout)
CREATE OR REPLACE FUNCTION deduct_funds(user_id_param UUID, amount_param DECIMAL, booking_id_param UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_balance DECIMAL;
BEGIN
    -- Get current balance
    SELECT wallet_balance INTO current_balance
    FROM profiles
    WHERE id = user_id_param;

    -- Check if sufficient funds
    IF current_balance < amount_param THEN
        RAISE EXCEPTION 'Insufficient wallet balance';
    END IF;

    -- Deduct balance
    UPDATE profiles
    SET wallet_balance = wallet_balance - amount_param,
        updated_at = NOW()
    WHERE id = user_id_param;

    -- Insert transaction record
    INSERT INTO transactions (user_id, amount, type, status, reference_id)
    VALUES (user_id_param, amount_param, 'booking_deduction', 'Completed', booking_id_param::varchar);
END;
$$;
