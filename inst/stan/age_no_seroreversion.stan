functions {
  #include functions/prob_infected_age.stan
}

data {
  #include data/basic_data.stan
  #include data/foi_prior_data.stan
}

transformed data {
  int n_foi = max(foi_index);
}

parameters {
  vector<lower=0>[n_foi] foi_vector;
  real<lower=0> sigma;
}

transformed parameters {
  vector[n_observations] prob_infected;

  prob_infected = prob_infected_age_model(
    age_groups,
		n_observations,
    foi_vector,
    foi_index,
    0.0
  );
}

model {
  n_seropositive ~ binomial(n_sample, prob_infected);
  sigma ~ cauchy(foi_sigma_rw_sc, foi_sigma_rw_sc);

  // force of infection prior
  if (foi_prior_index == 0)
    foi_vector[1] ~ uniform(foi_min, foi_max);
  if (foi_prior_index == 1)
    foi_vector[1] ~ normal(foi_mean, foi_sd);

  for(i in 2:n_foi)
    foi_vector[i] ~ normal(foi_vector[i - 1], sigma);
}

generated quantities{
  #include generated_quantities/log_likelihood.stan

  vector[age_max] prob_infected_expanded;
  vector[age_max] foi_expanded;

  for(age in 1:age_max) {
    foi_expanded[age] = foi_vector[foi_index[age]];
  }

	prob_infected_expanded = prob_infected_age_model(
		ages,
		age_max,
		foi_vector,
		foi_index,
		0.0
	);
}
