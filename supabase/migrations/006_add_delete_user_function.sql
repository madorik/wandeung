-- climbing_gyms.created_by 외래키를 ON DELETE SET NULL로 변경
ALTER TABLE climbing_gyms
  DROP CONSTRAINT IF EXISTS climbing_gyms_created_by_fkey,
  ADD CONSTRAINT climbing_gyms_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- 사용자가 자신의 auth 계정을 삭제할 수 있는 함수
CREATE OR REPLACE FUNCTION delete_own_user()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  DELETE FROM auth.users WHERE id = auth.uid();
$$;
