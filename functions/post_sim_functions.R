# Functions for summarizing dataframes, calculating point estimates and plotting

### SUMMARY FUNCTIONS

# This function is for summing the data, name is what it will be plot by 
sum_data <- function(dataframe, name = "", baseline, status, degree){
  failed <- dataframe %>% filter(is.na(adopters))
  failed_nets <- unique(failed$network)
  success_sims <- dataframe %>% subset(!(network %in% failed_nets))
  summed_data <- success_sims %>% group_by(round) %>% summarise(sumadopt = mean(adopters),
                                                             sd = sd(adopters),
                                                             name = name,
                                                             baseline = baseline, 
                                                             status = status, 
                                                             degree = degree)
  print(paste("Number of simulations for", 
              name, 
              "baseline", 
              baseline, 
              "status",
              status,
              "degree",
              degree,
              "that failed is:", length(failed_nets)))
  return(summed_data)
}

# For getting mean degree distribution across iterations
mean_degree <- function(degree_distributions){
  mean_degree <- degree_distributions %>% 
    dplyr::group_by(n_neighbors) %>% 
    dplyr::summarise(mean_n = mean(n, na.rm = T),
                     sd_n = sd(n, na.rm = T))
  
  return(mean_degree)
}

# For getting quantile point estimates of saturations
calculate_point_estimates <- function(dataframe, name, saturations){
  all <- data.frame(name=name)
  failed <- dataframe %>% filter(is.na(adopters))
  failed_nets <- unique(failed$network)
  success_sims <- dataframe %>% subset(!(network %in% failed_nets))
  for (point in saturations){
    q = success_sims %>% subset(adopters >= 3600*point)%>% group_by(network) %>% summarise(minround = min(round))
    q_mean = round(mean(q$minround),0)
    q_sd   = round(sd(q$minround),2)
    all[[paste0("mean", point, sep="_")]] <- q_mean
    all[[paste0("sd", point, sep="_")]] <- q_sd
  }
  return(all)
}

# Automatically sum simulation results, takes list of folders that are all in a data folder as input
# Outputs the summed results, the degree distributions and the point estimates of saturation
sum_multiple_results <- function(folders, saturations){
  all_data_sum = data.frame()
  degree_distributions <- data.frame()
  point_estimates <- data.frame()
  
  for (folder in folders){
    # Split folder name to extract information 
    split = strsplit(folder, "_|/") # Split by _ OR /
    
    # Read files
    results <- read.csv(paste(folder, "/simulation_results.csv", sep=""))
    degree_distribution <- read.csv(paste(folder, "/degree_distribution.csv", sep=""), fill = T)
    
    # Extra columns degree distribution 
    degree_distribution$baseline <- FALSE
    degree_distribution$status <- FALSE
    degree_distribution$degree <- FALSE
    degree_distribution$name <- paste(split[[1]][length(split[[1]])], "high status nodes")
    
    # Baseline files
    if (split[[1]][2] == "NoHigh"){
      # Summarise diffusion 
      summed_data <- sum_data(results, name = paste(split[[1]][length(split[[1]])], "high status nodes"), T, F, F)
      
      # Summarise degree distribution
      degree_distribution$baseline <- TRUE
      
      # Summarise point estimates
      points <- calculate_point_estimates(results, 
                                          name = paste("Baseline", split[[1]][length(split[[1]])], "high status nodes"),
                                          saturations = saturations)
      
    } 
    # High status files
    else if (split[[1]][4] == "highStatus"){
      # Summarise diffusion 
      summed_data <- sum_data(results, name = paste(split[[1]][3], "high status nodes"), 
                              F, split[[1]][length(split[[1]])], F)
      
      # Summarise degree distribution
      degree_distribution$status <- split[[1]][length(split[[1]])]
      
      # Summarise point estimates
      points <- calculate_point_estimates(results, name = paste("Highstatus =", 
                                                                split[[1]][length(split[[1]])], 
                                                                "with",
                                                                split[[1]][3], 
                                                                "high status nodes"),
                                          saturations = saturations)
    } 
    
    # High degree files 
    else if (split[[1]][4] == "highDegree"){
      # Summarise diffusion 
      summed_data <- sum_data(results, name = paste(split[[1]][3], "high status nodes"), 
                              F, F, split[[1]][length(split[[1]])])
      
      # Summarise degree distribution
      degree_distribution$degree <- split[[1]][length(split[[1]])]
      
      # Summarise point estimates
      points <- calculate_point_estimates(results, name = paste("HighDegree =",
                                                                split[[1]][length(split[[1]])],
                                                                "with",
                                                                split[[1]][3],
                                                                "high status nodes"),
                                          saturations = saturations)
    } 
    # Combine this file with previous
    all_data_sum <- rbind(all_data_sum, summed_data)
    degree_distributions <- rbind(degree_distributions, degree_distribution)
    point_estimates <- rbind(point_estimates, points)
  } # Looped through all folder
  return (list(all_data_sum, degree_distributions, point_estimates)) 
}


### SUMMARY FUNCTIONS

# This function is for plotting a single simulation
plot_standard <- function(summed_dataframe, title = "",
                          x_name = "Rounds", y_name = "Number of activated nodes"){
  
  plot <- ggplot(summed_dataframe, aes(round, sumadopt, color = str_wrap(tau,20)))+
    geom_line(size = 1.2)+
    theme_minimal()+
    theme(text = element_text(size = 20, family = "serif"), legend.key.height = unit(1,"cm"))+
    scale_color_brewer(palette = "PuOr")+
    labs(title = title, x = x_name, y = y_name) # , color = "tau"
  return(plot)
}

# This function is for plotting several simulation by the name given in summarizing using sum_data or sum_multiple_results
plot_standard_by_name <- function(summed_dataframe, title = "",
                                  x_name = "Rounds", y_name = "Number of activated nodes"){
  
  plot <- ggplot(summed_dataframe, aes(round, sumadopt, color = str_wrap(name,20)))+
    geom_line(size = 1.2)+
    theme_minimal()+
    theme(text = element_text(size = 20, family = "serif"), 
          legend.key.height = unit(1,"cm"),
          legend.position = "bottom",
          legend.title = element_blank())+
    scale_color_brewer(palette = "Dark2")+
    labs(title = title, x = x_name, y = y_name, color = "Simulation")
  return(plot)
}




# Plotting degree distribution summarized with function mean_degree
plot_degree_distribution <- function(mean_df, title, xlab="Number of neighbors", ylab="Count"){
  
  plot <- ggplot(mean_df) +
    geom_bar(aes(x= n_neighbors,y=mean_n), stat="identity", fill ="white", color="black", width=1, size = 1.1) +
    geom_errorbar(aes(x=n_neighbors, ymin=mean_n-sd_n, ymax=mean_n+sd_n), width=0.7, color="gray20")+
    labs(x=xlab, y = ylab, title=title)+
    theme_calc()+
    theme(text = element_text(size = 20, family = "serif"))+
    scale_x_continuous(breaks = seq(0,length(mean_df$n_neighbors)), minor_breaks = 0)
  return(plot)
}




