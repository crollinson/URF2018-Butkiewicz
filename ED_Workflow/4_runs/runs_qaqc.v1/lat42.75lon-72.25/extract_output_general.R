# Script to extract monthly output from ED and put it into a netcdf 

path.base <- '/projectnb/dietzelab/paleon/ED_runs/MIP2_Region'

source(file.path(path.base, "0_setup", "model2netcdf.ED2.paleon.R"), chdir = TRUE)


site='lat42.75lon-72.25'
sitelat <- as.numeric(substr(site,4,8)) # lat from SAS run
sitelon <- as.numeric(substr(site,12,17)) # insert site longitude(s) here
block.yr=100 # number of years you want to write into each file


raw.dir <- '/projectnb/dietzelab/paleon/ED_runs/MIP2_Region/4_runs/phase2_runs.v1/lat42.75lon-72.25'
new.dir <- '/projectnb/dietzelab/paleon/ED_runs/MIP2_Region/4_runs/runs_qaqc.v1/lat42.75lon-72.25'

if(!dir.exists(new.dir)) dir.create(new.dir)

flist <- dir(file.path(raw.dir, "analy/"),"-E-") # Getting a list of what has been done
  
# Getting a list of years that have been completed
yr <- rep(NA,length(flist)) # create empty vector the same length as the file list

for(i in 1:length(flist)){
    index <- gregexpr("-E-",flist[i])[[1]] # Searching for the monthly data marker (-E-); returns 3 bits of information: 1) capture.start (4); 2) capture.length (3); 3) capture.names (TRUE)
    index <- index[1] # indexing off of just where the monthly flag starts
    yr[i] <- as.numeric(substr(flist[i],index+3,index+6)) # putting in the Years, indexed off of where the year starts & ends
}  
  
start.run <- as.Date(paste0(min(yr), "-01-01"), "%Y-%m-%d")
end.run <- as.Date(paste0(max(yr), "-01-01"), "%Y-%m-%d")
bins <- c(as.numeric(strftime(start.run, '%Y')), seq(from=as.numeric(paste0(substr(as.numeric(strftime(start.run, "%Y"))+block.yr, 1, 2), "00")), to=as.numeric(strftime(end.run, '%Y')), by=block.yr)) # Creating a vector with X year bins for the time period of interest

print(paste0("----------  Processing Site: ", site, "  ----------")) 
  
model2netcdf.ED2.paleon(site, raw.dir, new.dir, sitelat, sitelon, start.run, end.run, bins)
