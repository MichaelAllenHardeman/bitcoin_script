
with AUnit; use AUnit;
with AUnit.Test_Cases; use AUnit.Test_Cases;

pragma Elaborate_All (AUnit);
pragma Elaborate_All (AUnit.Test_Cases);

package Bitcoin.Crypto.RIPEMD160_Tests is

  type TC is new Test_Cases.Test_Case with null record;

  function Name (T : TC) return Message_String is (Aunit.Format ("Bitcoin.Crypto.RIPEMD160"));

  overriding procedure Register_Tests (T : in out TC);

  procedure Test_Digest (Test : in out Test_Cases.Test_Case'Class);
end;
