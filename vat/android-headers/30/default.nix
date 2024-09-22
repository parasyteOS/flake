{
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "android-headers";
  version = "30";

  src = fetchFromGitHub {
    owner = "Linux-on-droid";
    repo = "android-headers-30";
    rev = "a6261c5cce8e945868b68318e867e382dea4bffd";
    hash = "sha256-J+bp+IEoyqeTNo3XDu4OaWLlA+d3GOptxP4sCVfshow=";
  };

  dontBuild = true;
  makeFlags = ["PREFIX=${placeholder "out"}"];
}
