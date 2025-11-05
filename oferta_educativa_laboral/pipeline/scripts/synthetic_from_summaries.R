# synthetic_from_summaries.R
# Simulacion de datos SIAP para unit tests
# Summary stats plus df_col manual QNA 07 2025

# Inputs:
# sum_chars.txt
# sum_dates.txt
# sum_factors.txt
# sum_stats.txt
# df_col_types2_utf8.csv

# ouputs sim df as csv or parquet

# Notas:
# Recrear el tipo de cada columna, la proporción de valores faltantes y la distribución marginal aproximada a partir de resúmenes generados de datos reales (sum_chars, sum_stats, etc.)
# Para columnas numéricas: normal truncada en [min,max] salvo que los cuartiles muestren un pico fuerte en 0; en ese caso usar normal/log-normal con inflación de ceros.
# Para columnas de fecha: muestreador empírico usando min / cuartiles / max y un pico centinela (p. ej., 2050-01-01 en algunos campos).
# Para columnas categóricas: muestrear de la lista de frecuencias observadas ("top counts" en sum_factors.txt), si no hay información usar “Otro_*”.
# Para identificadores (CURP/RFC/NSS/MATRICULA): generar cadenas aleatorias con formato/longitud plausibles.
# Inyectar NA para que coincidan las tasas por columna (desde "na_perc.txt")

# La inyección de NA usa las tasas por columna para que los tests encuentren los mismos patrones de datos faltantes (p. ej., SEXO, RFC, CURP, NSS ~7.68% NA).
# Ceros abundantes/asimetrías (p. ej., IMP_035 con q25=0, q50=0, q75=0) se tratan como inflación de ceros. El min/max observado se recorta para mantener valores extremos dentro de los límites conocidos.
# Fechas centinela (IQR=0 alrededor de 2050-01-01 para campos como FECHALIMOCU) reciben una probabilidad de pico.
# Los IDs respetan la longitudes del string (p. ej., CURP 16–18, RFC 13, NSS 10–11, MATRICULA 6–9).
# Las categóricas se muestrean de los niveles más frecuentes observados con una cola residual “Otro_*” para ajustar la cardinalidad (n_unique).

# Para aproximar mejor las marginales reales (probablemente no necesario):
# Reemplazar los muestreadores numéricos y de fecha por funciones inversas de la CDF por tramos (piecewise-linear) construidas a partir de múltiples cuantiles;
# si se requiere estructura de dependencia, añadir una cópula gaussiana sobre las mismas marginales. Requiere una matriz de correlación.

# TO DO:
# Line by line docs

# ---- Libraries ----
library(readr)
library(dplyr)
library(tidyr)
library(purrr)
library(stringr)
library(stringi)
library(lubridate)

# --- params ----
N_OUT <- 5000 # n samples
# SEED <- 20251105L # reproducibility
SEED <- 39453475L # reproducibility
subdir <- "25_04_2025_Qna_07_Plantilla_2025_meds_report_freeze"
PATHS <- list(
  na_perc = file.path(subdir, "na_perc.txt"),
  sum_chars = file.path(subdir, "sum_chars.txt"),
  sum_dates = file.path(subdir, "sum_dates.txt"),
  sum_facts = file.path(subdir, "sum_factors.txt"),
  sum_nums = file.path(subdir, "sum_stats.txt"),
  col_types = file.path("df_col_types2_utf8.csv") # optional; used if present
)

set.seed(SEED)

# ---- utils ----
read_tsv_loose <- function(path) {
  readr::read_tsv(path, show_col_types = FALSE, progress = FALSE)
}

parse_top_counts <- function(x) {
  if (is.null(x) || is.na(x) || !nzchar(x)) {
    return(tibble(level = character(), n = integer()))
  }
  # tolerate em dashes or other non-std placeholders
  if (grepl("^\\s*(-+|—+)\\s*$", x)) {
    return(tibble(level = character(), n = integer()))
  }
  toks <- strsplit(x, ",\\s*")[[1]]
  m1 <- stringr::str_match(toks, "^(.*)\\s*\\((\\d+)\\)\\s*$")
  # keep only rows that match:
  ok <- which(!is.na(m1[, 2]) & !is.na(m1[, 3]))
  if (!length(ok)) {
    return(tibble(level = character(), n = integer()))
  }
  tibble(
    level = stringr::str_trim(m1[ok, 2]),
    n = as.integer(m1[ok, 3])
  )
}

normalize_probs <- function(p) {
  p[!is.finite(p)] <- 0
  s <- sum(p)
  if (s <= 0 || is.na(s)) rep(1 / length(p), length(p)) else p / s
}

make_factor_sampler <- function(
  name,
  top_counts_row,
  n_unique,
  fallback_levels = 5
) {
  tc <- parse_top_counts(top_counts_row)

  if (nrow(tc) == 0) {
    # no info: synthetic balanced levels
    k <- max(
      3,
      fallback_levels,
      ifelse(is.finite(n_unique) && n_unique > 0, min(n_unique, 12), 5)
    )
    lvls <- paste0(name, "_", seq_len(k))
    p <- rep(1 / k, k)
    return(function(n) sample(lvls, n, TRUE, p))
  }

  # ---- base levels + probabilities ----
  lv <- tc$level
  cnt <- tc$n
  cnt[!is.finite(cnt) | is.na(cnt) | cnt < 0] <- 0
  if (sum(cnt) == 0) {
    cnt <- rep(1L, length(cnt))
  }

  p <- normalize_probs(cnt)

  # optional long tail to match n_unique
  tail_k <- max(0, as.integer(n_unique) - length(lv))
  if (is.finite(tail_k) && tail_k > 0) {
    p <- p * 0.9
    p_Otro <- 0.1
    lv <- c(lv, paste0("Otro_", seq_len(tail_k)))
    p <- c(p, rep(p_Otro / tail_k, tail_k))
  }

  p <- normalize_probs(p) # guard / check
  function(n) sample(lv, n, TRUE, p)
}

clip <- function(x, lo, hi) pmin(pmax(x, lo), hi)

r_zero_infl <- function(n, p0, rpos) {
  i0 <- rbinom(n, 1, p0) == 1
  out <- numeric(n)
  out[!i0] <- rpos(sum(!i0))
  out
}

# ---- numeric sampler ----

# all samplers mimic summary stats from inputs
make_numeric_sampler <- function(row) {
  minv <- as.numeric(row$min)
  maxv <- as.numeric(row$max)
  meanv <- as.numeric(row$mean)
  sdv <- as.numeric(row$SD)
  q25 <- as.numeric(row$quantile_25)
  q50 <- as.numeric(row$median)
  q75 <- as.numeric(row$quantile_75)

  spike_zero <- (!is.na(q25) && !is.na(q75) && q25 == 0 && q50 == 0 && q75 == 0)

  if (isTRUE(spike_zero)) {
    # Heuristic: zero inflation if central mass is at 0
    p0 <- 0.75
    # positive tail: log-normal from mean/sd magnitude if possible, else normal
    mu <- log(abs(meanv) + 1)
    s <- log((sdv + 1) / 2 + 1)
    function(n) {
      r_zero_infl(n, p0, function(k) {
        vals <- rlnorm(k, meanlog = mu, sdlog = max(0.3, s))
        # allow occasional negative as in some IMP_* min values
        sgn <- if (minv < 0) sample(c(-1, 1), k, TRUE, c(0.1, 0.9)) else 1
        clip(vals * sgn, minv, maxv)
      })
    }
  } else {
    # Truncated normal with moment-matching
    function(n) {
      vals <- rnorm(n, meanv, ifelse(is.finite(sdv) && sdv > 0, sdv, 1))
      clip(vals, minv, maxv)
    }
  }
}

# ---- date sampler ----

# (min,q25,median,q75,max, most common)
make_date_sampler <- function(row) {
  asD <- function(x) lubridate::as_date(x)
  dmin <- asD(row$Min)
  d25 <- asD(row$`25%`)
  d50 <- asD(row$Median)
  d75 <- asD(row$`75%`)
  dmax <- asD(row$Max)
  dmode <- asD(row$`Most Common`)

  spike_mode <- !is.na(dmode) && !is.na(d25) && !is.na(d75) && d25 == d75

  rng <- function(k, a, b) {
    as.Date(
      runif(k, min = as.numeric(a), max = as.numeric(b)),
      origin = "1970-01-01"
    )
  }

  function(n) {
    out <- as.Date(rep(NA_integer_, n), origin = "1970-01-01")
    if (spike_mode) {
      spike <- runif(n) < 0.6
      out[spike] <- dmode
      not_spike_idx <- which(!spike)
      k <- length(not_spike_idx)
      if (k > 0) {
        u2 <- runif(k)
        a_idx <- not_spike_idx[u2 < 0.5]
        b_idx <- setdiff(not_spike_idx, a_idx)
        if (length(a_idx) > 0) {
          out[a_idx] <- rng(length(a_idx), dmin, d50)
        }
        if (length(b_idx) > 0) out[b_idx] <- rng(length(b_idx), d50, dmax)
      }
    } else {
      u <- runif(n)
      lo_idx <- which(u < 0.2)
      mid_idx <- which(u >= 0.2 & u < 0.8)
      hi_idx <- which(u >= 0.8)
      if (length(lo_idx)) {
        out[lo_idx] <- rng(length(lo_idx), dmin, d25)
      }
      if (length(mid_idx)) {
        out[mid_idx] <- rng(length(mid_idx), d25, d75)
      }
      if (length(hi_idx)) out[hi_idx] <- rng(length(hi_idx), d75, dmax)
    }
    out
  }
}

# ---- categorical sampler ----
make_factor_sampler <- function(
  name,
  top_counts_row,
  n_unique,
  fallback_levels = 5
) {
  tc <- parse_top_counts(top_counts_row)
  if (nrow(tc) == 0) {
    # create synthetic levels if none provided
    lvls <- paste0(name, "_", seq_len(max(3, fallback_levels)))
    p <- rep(1 / length(lvls), length(lvls))
    return(function(n) sample(lvls, n, TRUE, p))
  }
  p <- tc$n / sum(tc$n)
  lv <- tc$level

  # Account for a long tail by allocating small prob mass to "Otro"
  tail_k <- max(0, n_unique - length(lv))
  if (tail_k > 0) {
    p <- p * 0.9
    p_Otro <- 0.1
    lv <- c(lv, paste0("Otro_", seq_len(tail_k)))
    p <- c(p, rep(p_Otro / tail_k, tail_k))
  }
  function(n) sample(lv, n, TRUE, p)
}

# ---- fake identifiers ----
r_alnum <- function(n, len) stri_rand_strings(n, len, pattern = "[A-Z0-9]")
r_upper <- function(n, len) stri_rand_strings(n, len, pattern = "[A-Z]")

gen_CURP <- function(n) {
  # 18 chars typical
  paste0(
    r_upper(n, 4),
    stri_rand_strings(n, 6, "[0-9]"),
    r_upper(n, 6),
    stri_rand_strings(n, 2, "[0-9]")
  )
}
gen_RFC <- function(n) {
  stri_rand_strings(n, 13, "[A-Z0-9]")
}
gen_NSS <- function(n) {
  stri_rand_strings(n, 11, "[0-9]")
}
gen_MATRICULA <- function(n) {
  stri_rand_strings(n, sample(6:9, n, TRUE), "[0-9]")
}

# ---- read summaries ----
na_tbl <- read_tsv_loose(PATHS$na_perc) # columns: needs 'var' col, input manually
char_tbl <- read_tsv_loose(PATHS$sum_chars) # CURP/RFC/NSS/MATRICULA lengths
date_tbl <- read_tsv_loose(PATHS$sum_dates)
fact_tbl <- read_tsv_loose(PATHS$sum_facts)
num_tbl <- read_tsv_loose(PATHS$sum_nums)

# optional column types
col_types <- tryCatch(
  readr::read_csv(PATHS$col_types, show_col_types = FALSE),
  error = \(e) NULL
)

# ---- build generators per column ----
gens <- list()

## Numeric
if (nrow(num_tbl)) {
  # ensure consistent names
  num_tbl <- num_tbl %>% rename(var = id)
  for (i in seq_len(nrow(num_tbl))) {
    row <- num_tbl[i, ]
    gens[[row$var]] <- make_numeric_sampler(row)
  }
}

## Dates
if (nrow(date_tbl)) {
  # normalise headers (as readr might coerce)
  names(date_tbl) <- c(
    "Column",
    "N",
    "N Missing",
    "N Unique",
    "Min",
    "25%",
    "Median",
    "75%",
    "Max",
    "IQR",
    "Most Common",
    "Range (Days)"
  )
  for (i in seq_len(nrow(date_tbl))) {
    row <- date_tbl[i, ]
    gens[[row$Column]] <- make_date_sampler(row)
  }
}

## Factors
if (nrow(fact_tbl)) {
  fact_tbl <- fact_tbl %>% rename(var = Variable)
  for (i in seq_len(nrow(fact_tbl))) {
    row <- fact_tbl[i, ]
    gens[[row$var]] <- make_factor_sampler(
      row$var,
      row$top_counts,
      as.integer(row$n_unique)
    )
  }
}

## Characters / IDs
id_names <- c("CURP", "RFC", "NSS", "MATRICULA")
for (nm in intersect(id_names, char_tbl$Variable)) {
  gens[[nm]] <- switch(
    nm,
    CURP = function(n) gen_CURP(n),
    RFC = function(n) gen_RFC(n),
    NSS = function(n) gen_NSS(n),
    MATRICULA = function(n) gen_MATRICULA(n)
  )
}

# any columns not covered but present in NA table -> simple placeholders
for (nm in setdiff(na_tbl$var, names(gens))) {
  gens[[nm]] <- function(n) rep(NA_character_, n)
}

# ---- simulate ----
simulate_dataset <- function(n = N_OUT) {
  out <- vctrs::df_list()
  for (nm in names(gens)) {
    out[[nm]] <- gens[[nm]](n)
  }
  df <- tibble::as_tibble(out)

  # Apply NA masks by column (match percentages)
  if (nrow(na_tbl)) {
    meta <- na_tbl %>%
      transmute(var = .data$var, na_perc = as.numeric(.data$na_perc) / 100)

    for (i in seq_len(nrow(meta))) {
      v <- meta$var[i]
      if (!v %in% names(df)) {
        next
      }
      p <- meta$na_perc[i]
      if (is.na(p) || p <= 0) {
        next
      }
      idx <- if (p > 0) {
        sample.int(nrow(df), size = max(1L, floor(p * nrow(df))))
      } else {
        integer()
      }
      df[[v]][idx] <- NA
    }
  }

  # Minimal cross-field constraints (end dates after ini dates)
  date_cols <- intersect(
    c("FECHAINI", "FECHAOCUP", "FECHAMOV", "FECHAFIN"),
    names(df)
  )
  if (all(c("FECHAINI", "FECHAFIN") %in% date_cols)) {
    swap <- which(df$FECHAFIN < df$FECHAINI)
    if (length(swap)) {
      tmp <- df$FECHAFIN[swap]
      df$FECHAFIN[swap] <- df$FECHAINI[swap]
      df$FECHAINI[swap] <- tmp
    }
  }

  df
}

syn <- simulate_dataset(N_OUT)

syn


# ---- save ----
readr::write_csv(syn, "synthetic_dataset2.csv")
if (requireNamespace("arrow", quietly = TRUE)) {
  arrow::write_parquet(syn, "synthetic_dataset2.parquet")
}

# library(episcout)
# df <- epi_read("synthetic_dataset2.csv")
# epi_head_and_tail(df)
# dim(df)
# epi_clean_count_classes(df)
