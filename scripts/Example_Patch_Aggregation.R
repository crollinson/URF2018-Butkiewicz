library(ncdf4)
ncT <- nc_open("extracted_output.v3/CD-SC-FY-TH-IM/ED2.1955.nc")

# cohort --> patch --> site

table.patch <- data.frame(ncvar_get(ncT,"Cohort_PatchID"))
table.pft <- data.frame(ncvar_get(ncT, "Cohort_PFT"))
table.agb <- data.frame(ncvar_get(ncT, "Cohort_AbvGrndBiom"))
table.dens <- data.frame(ncvar_get(ncT, "Cohort_Density"))
table.dbh <- data.frame(ncvar_get(ncT, "Cohort_DBH"))
 
dat.cohort <- data.frame(month=rep(1:ncol(table.pft),each=nrow(table.pft)),
                         patch = stack(table.patch)[,1],
                         pft = stack(table.pft)[,1], # kgC/m2
                         dens = stack(table.dens)[,1], # trees/m2
                         dbh = stack(table.dbh)[,1]) # DBH/tree

dat.cohort <- data.frame(patch = ncvar_get(ncT, "Cohort_PatchID")[,6], #Just looking at the month of June here. 
                          pft   = ncvar_get(ncT, "Cohort_PFT")[,6], 
                          agb   = ncvar_get(ncT, "Cohort_AbvGrndBiom")[,6], # kgC/m2
                          dens  = ncvar_get(ncT, "Cohort_Density")[,6], # trees/m2
                          dbh   = ncvar_get(ncT, "Cohort_DBH")[,6]) # DBH/tree
                          
# Calculate the DBH weight for each cohort usign a loop!
dat.cohort$p.dens <- NA # creating a placeholder column
dat.cohort$p.dbh <- NA # creating a placeholder column
dat.cohort$dbh.tree <- ifelse(dat.cohort$dbh>=10, dat.cohort$dbh, NA) #Puts a size threshold on the trees so that we're not considering saplings. 

# Basically, "variable" is the measurement of every single tree in the patch. 
#            "variable.tree" is the measurement of every tree with a dbh >10 cm. 
#            "p.variable" is the measurement weighted by patch area, which in ED is outputted as a proportion and has 
#             no units. 

dat.cohort$dens.tree <- ifelse(dat.cohort$dbh>=10, dat.cohort$dens, NA) #Ignores cohort densities where the trees are below that threshold value. 
dat.cohort$p.dbh.tree <- NA #creates a placeholder column, which will be the tree DBH weighted by patch area. 
dat.cohort$p.dens.tree <- NA #creates a placeholder column, which will be the tree density weighted by patch area. 

for(PCH in unique(dat.cohort$patch)){
	for(PFT in unique(dat.cohort$pft)){
		row.ind <- which(dat.cohort$patch==PCH & dat.cohort$pft==PFT) # row numbers for this group 
		
		dat.tmp <- dat.cohort[row.ind,] # subset our data to something small for our sanity
		dens.tot <- sum(dat.tmp$dens) # sum of cohort densities by patch and PFT. 
		dens.tree <- sum(dat.tmp$dens.tree, na.rm=T) # total density of the trees with a DBH above our threshold value. 
		
		dat.tmp$p.dens <- dat.tmp$dens/dens.tot # density weighed by patch area, filled in. 
		dat.tmp$p.dens.tree  <- dat.tmp$dens.tree/dens.tree # density of trees above our DBH weighted by patch area
		dat.tmp$p.dbh  <- dat.tmp$dbh * dat.tmp$p.dens 
		dat.tmp$p.dbh.tree  <- dat.tmp$dbh.tree * dat.tmp$p.dens.tree
		
		dat.cohort[row.ind,c("p.dens", "p.dbh", "p.dens.tree", "p.dbh.tree")] <- dat.tmp[,c("p.dens", "p.dbh", "p.dens.tree", "p.dbh.tree")] # put the new values into our table
	} # Close PFT loop
} # Close PCH (patch) loop                    
                          
dat.patch <- aggregate(dat.cohort[,c("agb", "dens", "p.dbh", "dens.tree", "p.dbh.tree")], by=dat.cohort[,c("patch", "pft")], FUN=sum, na.rm=T)
dat.patch$dbh.max <- round(aggregate(dat.cohort$dbh, by=dat.cohort[,c("patch", "pft")], FUN=max)[,"x"],2) # rounding to 2 decimal places
names(dat.patch) <- car::recode(names(dat.patch), "'p.dbh'='dbh'; 'p.dbh.tree'='dbh.tree'")

patch.area <- ncvar_get(ncT, "Patch_Area")[,6]
patch.area <- data.frame(patch = 1:length(patch.area),
                          area  = patch.area)

dat.patch <- merge(dat.patch, patch.area, all.x=T)

dat.patch[dat.patch$dens.tree==0, "dbh.tree"] <- NA
dat.patch$p.agb <- dat.patch$agb * dat.patch$area
dat.patch$p.dens <- dat.patch$dens * dat.patch$area
dat.patch$p.dbh <- dat.patch$dbh * dat.patch$area
dat.patch$p.dens.tree <- dat.patch$dens.tree * dat.patch$area
dat.patch$p.dbh.max <- dat.patch$dbh.max * dat.patch$area

# For trees, we need to weight by area of patches with TREES
area.tree <- dat.patch[dat.patch$pft==10 & !is.na(dat.patch$dbh.tree),"area"]
dat.patch$p.dbh.tree <- dat.patch$dbh.tree * dat.patch$area/sum(area.tree)

dat.site <- aggregate(dat.patch[,c("p.agb", "p.dens", "p.dbh", "p.dens.tree", "p.dbh.tree", "p.dbh.max")], by=list(dat.patch$pft), FUN=sum, na.rm=T)
dat.site$dbh.max <- aggregate(dat.patch[,"dbh.max"], by=list(dat.patch$pft), FUN=max)[,"x"]
dat.site