# Carrega as funcoes de R/ antes de rodar os testes.
# testthat::test_dir()/test_file() mudam o diretorio de trabalho para
# tests/testthat durante a execucao, entao o caminho e relativo a esta
# pasta (dois niveis acima = raiz do repositorio).
.dir_r <- file.path("..", "..", "R")
for (arquivo in list.files(.dir_r, pattern = "\\.R$", full.names = TRUE)) {
  source(arquivo)
}
