real prob_infected_age_model_single_age(
  int age,
  vector foi_vector,
  array[] int foi_index,
  real seroreversion_rate
) {
  real prob = 0.0;
  for(j in 1:age){
    real foi = foi_vector[foi_index[j]];
    real lambda_over_both = foi / (foi + seroreversion_rate);
    real e_lower = exp(-(foi + seroreversion_rate));

    prob = lambda_over_both + e_lower * (prob - lambda_over_both);
  }
  return prob;
}

vector prob_infected_age_model(
	array[] int ages,
	int n_ages,
	vector foi_vector,
	array[] int foi_index,
	real seroreversion_rate
) {
	vector[n_ages] prob_infected;

	for (i in 1:n_ages) {
		prob_infected[i] = prob_infected_age_model_single_age(
			ages[i],
			foi_vector,
			foi_index,
			seroreversion_rate
		);
	}
	return prob_infected;
}
