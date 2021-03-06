## LIBRARIES ----------------------------------------------

library(rgdal)
library(rgeos)
library(stringr)
library(dplyr)
library(tmaptools)
library(sp)
library(ggplot2)
library(plyr)
library(viridis)
library(scales)
library(ggplot2)
library(ggrepel)

setwd("~/Google Drive/SDAL/SCHEV (Peter Blake - Wendy Kang)/")

## PREPARE COUNTY & SCHOOL BOUNDARY SHAPEFILES ----------------------------------------------
# import school crosswalk
sch_cw<-read.csv("Code/Bianica/school_crosswalk.csv")
# import school boundary shapefile 
boundaries <- read_shape("Data/School Attendance Boundaries/SABS_1314_SchoolLevels/SABS_1314_High.shp")
# filter for schools in virginia
va_boundaries <- boundaries[which(str_sub(as.character(boundaries$leaid),1,2)=="51"),] # Virginia
# get school names we're interested in
sch_names<-left_join(sch_cw,va_boundaries@data,by=c("sch_names"="schnam"))
sch_names<-sch_names$sch_names
# filter for schools in study area
sch_boundaries <- va_boundaries[which(va_boundaries$schnam %in% sch_names),] # study area
# filter out high schools not in study area
sch_boundaries <- sch_boundaries[which(sch_boundaries$ncessch!=510390001749),]
sch_boundaries <- sch_boundaries[which(sch_boundaries$ncessch!=510183000776),]
sch_boundaries <- sch_boundaries[which(sch_boundaries$ncessch!=510411001801),]
sch_boundaries <- sch_boundaries[which(sch_boundaries$ncessch!=510126002034),]
sch_boundaries <- sch_boundaries[which(sch_boundaries$schnam!="ROCKY GAP HIGH"),]
# add clean school name to shapefile data
boundary_data<-left_join(sch_boundaries@data,sch_cw,by=c("schnam"="sch_names"))
sch_boundaries@data<-boundary_data
# import county shapefile
usa <- read_shape("~/Downloads/cb_2017_us_county_5m/cb_2017_us_county_5m.shp")
# filter for Virginia
virginia <-usa[usa@data$STATEFP==51,]
# transform CRS of virginia to that of sch_boundaries
virginia_t <- spTransform(virginia, CRS(proj4string(sch_boundaries)))

# plot
plot(virginia_t)
plot(sch_boundaries, col="red", add=T)

# prepare for ggplot presentation
sch_boundaries@data$id = rownames(sch_boundaries@data)
sch_boundaries.points = fortify(sch_boundaries, region="id")
sch_boundaries.df = join(sch_boundaries.points, sch_boundaries@data, by="id")

virginia_t@data$id = rownames(virginia_t@data)
virginia_t.points = fortify(virginia_t, region="id")
virginia_t.df = join(virginia_t.points, virginia_t@data, by="id")

## PREPARE VDOE DATA FOR MAPS ----------
vdoe <- read.csv("Code/Bianica/vdoe_psEnrollmentDataForMaps.csv")

map_data <- left_join(x=vdoe, y=sch_boundaries.df, by = "sch_name_clean")



## VIRIDIS PREP ----
variable = data1$totalProp_4YearCollegeEnrollment
title = "Proportion of students enrolling in 4-year colleges"
file_path = "Code/Maddie/output/publication_maps/map_prop_4year.pdf" 
legend_position = c(0.22, 0.85)

viridis_mapVA <- function(variable, title, file_path, legend_position){
    minVal <- 0
    maxVal <- 1
    
    n=10
    x=(maxVal-minVal)/n
    pretty_breaks<-rep(0,n-1)
    
    for(i in 1: length(pretty_breaks)) {
        if(i==1) {
            pretty_breaks[1]=minVal+x
        } else {
            pretty_breaks[i]=pretty_breaks[i-1]+x
        }
    }
    
    # compute labels
    labels <- c()
    brks <- c(minVal, pretty_breaks, maxVal)
    # round the labels (actually, only the extremes)
    for(idx in 1:length(brks)){
        labels <- c(labels,round(brks[idx + 1], 2))
    }
    
    labels <- labels[1:length(labels)-1]
    # define a new variable on the data set just as above
    data1$brks <- cut(variable, 
                      breaks = brks, 
                      include.lowest = TRUE, 
                      labels = labels)
    
    brks_scale <- levels(data1$brks)
    labels_scale <- rev(brks_scale)
    
    values=rev(magma(n))

    ggplot() +
        geom_polygon(data=data1,aes(long,lat,group=group,fill=brks))+
        scale_fill_manual(values = values,
                          breaks = rev(brks_scale),
                          name = title,
                          drop = FALSE,
                          labels = c(labels_scale[1],"","",labels_scale[4],"","",labels_scale[7],"","",labels_scale[10]),
                          guide = guide_legend(
                              direction = "horizontal",
                              keyheight = unit(4, units = "mm"),
                              keywidth = unit(60 / length(labels), units = "mm"),
                              title.position = 'top',
                              label.hjust = 1,
                              nrow = 1,
                              byrow = T,
                              # also the guide needs to be reversed
                              reverse = T,
                              label.position = "bottom")) +
        coord_equal(ratio=1) +
        theme_void() +
        geom_polygon(data=geoZips,aes(x=long,y=lat,group=group),fill=NA,color="grey50",size=0.25) +
        labs(x="", y="")+ #labels
        theme(axis.ticks.y = element_blank(),axis.text.y = element_blank(), # get rid of x ticks/text
              axis.ticks.x = element_blank(),axis.text.x = element_blank(), # get rid of y ticks/text
              panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
              legend.position = legend_position) +
        coord_equal(ratio=1) # square plot to avoid the distortion
    ggsave(file_path, device = "pdf", width=7,height=5, units = "in")
    
}

viridis_mapZOOM <- function(variable, title, file_path, legend_position, label_data){
    minVal <- 0
    maxVal <- .65
    
    n=10
    x=(maxVal-minVal)/n
    pretty_breaks<-rep(0,n-1)
    
    for(i in 1: length(pretty_breaks)) {
        if(i==1) {
            pretty_breaks[1]=minVal+x
        } else {
            pretty_breaks[i]=pretty_breaks[i-1]+x
        }
    }
    
    # compute labels
    labels <- c()
    brks <- c(minVal, pretty_breaks, maxVal)
    # round the labels (actually, only the extremes)
    for(idx in 1:length(brks)){
        labels <- c(labels,round(brks[idx + 1], 2))
    }
    
    labels <- labels[1:length(labels)-1]
    # define a new variable on the data set just as above
    data1$brks <- cut(variable, 
                      breaks = brks, 
                      include.lowest = TRUE, 
                      labels = labels)
    
    brks_scale <- levels(data1$brks)
    labels_scale <- rev(brks_scale)
    
    values=rev(magma(n))
    
    ggplot() +
        geom_polygon(data=data1,aes(long,lat,group=group,fill=brks), color = "grey50",size=0.25)+
        scale_fill_manual(values = values,
                          breaks = rev(brks_scale),
                          name = title,
                          drop = FALSE,
                          labels = c(labels_scale[1],"","",labels_scale[4],"","",labels_scale[7],"","",labels_scale[10]),
                          guide = guide_legend(
                              direction = "horizontal",
                              keyheight = unit(4, units = "mm"),
                              keywidth = unit(60 / length(labels), units = "mm"),
                              title.position = 'top',
                              label.hjust = 1,
                              nrow = 1,
                              byrow = T,
                              # also the guide needs to be reversed
                              reverse = T,
                              label.position = "bottom")) +
        coord_equal(ratio=1) +
        theme_void() +
        #geom_polygon(data=geoZips,aes(x=long,y=lat,group=group),fill=NA,color="grey50",size=0.25) +
        labs(x="", y="")+ #labels
        geom_label_repel(data = label_data, aes(label = gsub("High", "",id2), x = Longitude, y = Latitude), size = 2) +
        theme(axis.ticks.y = element_blank(),axis.text.y = element_blank(), # get rid of x ticks/text
              axis.ticks.x = element_blank(),axis.text.x = element_blank(), # get rid of y ticks/text
              panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
              legend.position = legend_position) +
        coord_equal(ratio=1) # square plot to avoid the distortion
    ggsave(file_path, device = "pdf", width=7,height=5, units = "in")
    
}

viridis_map <- function(variable, title, file_path, legend_position, label_data){
    minVal <- 0
    maxVal <- .65
    
    n=10
    x=(maxVal-minVal)/n
    pretty_breaks<-rep(0,n-1)
    
    for(i in 1: length(pretty_breaks)) {
        if(i==1) {
            pretty_breaks[1]=minVal+x
        } else {
            pretty_breaks[i]=pretty_breaks[i-1]+x
        }
    }
    
    # compute labels
    labels <- c()
    brks <- c(minVal, pretty_breaks, maxVal)
    # round the labels (actually, only the extremes)
    for(idx in 1:length(brks)){
        labels <- c(labels,round(brks[idx + 1], 2))
    }
    
    labels <- labels[1:length(labels)-1]
    # define a new variable on the data set just as above
    data1$brks <- cut(variable, 
                      breaks = brks, 
                      include.lowest = TRUE, 
                      labels = labels)
    
    brks_scale <- levels(data1$brks)
    labels_scale <- rev(brks_scale)
    
    values=rev(magma(n))
    
    ggplot() +
        geom_polygon(data=data1,aes(long,lat,group=group,fill=brks), color = "grey50",size=0.25)+
        scale_fill_manual(values = values,
                          breaks = rev(brks_scale),
                          name = title,
                          drop = FALSE,
                          labels = c(labels_scale[1],"","",labels_scale[4],"","",labels_scale[7],"","",labels_scale[10]),
                          guide = guide_legend(
                              direction = "horizontal",
                              keyheight = unit(4, units = "mm"),
                              keywidth = unit(60 / length(labels), units = "mm"),
                              title.position = 'top',
                              label.hjust = 1,
                              nrow = 1,
                              byrow = T,
                              # also the guide needs to be reversed
                              reverse = T,
                              label.position = "bottom")) +
        coord_equal(ratio=1) +
        theme_void() +
        geom_polygon(data=geoZips,aes(x=long,y=lat,group=group),fill=NA,color="grey50",size=0.25) +
        labs(x="", y="")+ #labels
        geom_label_repel(data = label_data, aes(label = gsub("High", "",id2), x = Longitude, y = Latitude), size = 2) +
        theme(axis.ticks.y = element_blank(),axis.text.y = element_blank(), # get rid of x ticks/text
              axis.ticks.x = element_blank(),axis.text.x = element_blank(), # get rid of y ticks/text
              panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
              legend.position = legend_position) +
        coord_equal(ratio=1) # square plot to avoid the distortion
    ggsave(file_path, device = "pdf", width=7,height=5, units = "in")
    
}

## VIRGINIA MAPS ------
data1 = map_data
geoZips = virginia_t

# two year
viridis_mapVA(variable = data1$totalProp_2YearCollegeEnrollment, 
            title = "Proportion of students enrolling in 2-year colleges",
            file_path = "Code/Maddie/output/publication_maps/map_prop_2year.pdf",
            legend_position = c(0.27, 0.86))

# four year
viridis_mapVA(variable = data1$totalProp_4YearCollegeEnrollment, 
            title = "Proportion of students enrolling in 4-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/map_prop_4year.pdf", 
            legend_position = c(0.27, 0.86))

# two year disadvantaged
viridis_mapVA(variable = data1$disadvY_2_year_ps_prop, 
            title = "Proportion of disadvantaged students \n enrolling in 2-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/map_prop_disadv2year.pdf", 
            legend_position = c(0.27, 0.86))

# four year disadvantaged
viridis_mapVA(variable = data1$disadvY_4_year_ps_prop, 
            title = "Proportion of disadvantaged students \n enrolling in 4-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/map_prop_disadv4year.pdf", 
            legend_position = c(0.27, 0.86))

# ASSIGN NEARBY COUNTIES TO STUDY REGIONS  -----
# surrounding counties/areas
bland_county <- c("Tazewell County", "Smyth County", "Wythe County", "Pulaski County", "Giles County", "Bland County")
buchanan_county <- c("Dickenson County", "Russell County", "Tazewell County", "Buchanan County")
roanoke_city <- c("Roanoke County", "Salem County", "Roanoke City")
roanoke_county <- c("Roanoke City","Montgomery County", "Floyd County", "Franklin County", "Bedford County", "Botetourt County", "Craig County", "Roanoke County")
richmond_city <- c("Chesterfield County", "Henrico County", "Richmond City")
sussex_county <- c("Prince George County", "Dinwiddie County", "Greensville County", "Southampton County", "Isle of Wight County", "Surry County", "Sussex County")
powhatan <- c("Goochland County", "Cumberland County", "Amelia County", "Chesterfield County", "Powhatan County")

# categorize counties into appalachia or richmond (for zoomed in maps)
# appalachia
appalachia.sch <- c(bland_county, buchanan_county, roanoke_county, roanoke_city) # use to subset school boundary polygon
#appalachia <- gsub(" .*", "", c(bland_county, buchanan_county, roanoke_county, roanoke_city)) # use to subset county polygon
appalachia <- virginia_t.df %>% filter(NAME %in% gsub(" .*", "", c(bland_county, buchanan_county, roanoke_county, roanoke_city))) %>% filter(long < 1500000)
#appalachia <- map_data %>% filter(county_name %in% appalachia.sch)

# richmond
eastern.sch <- c(richmond_city, sussex_county, powhatan)
eastern <-  gsub(" County", "", c(richmond_city, sussex_county, powhatan))
eastern <- gsub(" City", "", eastern)

# find centroids of each polygon for labeling schools
sch_boundaries.fort <- fortify(sch_boundaries, region = "sch_name_clean")
idList <- sch_boundaries@data$sch_name_clean
centroids.df <- as.data.frame(coordinates(sch_boundaries))
names(centroids.df) <- c("Longitude", "Latitude")
text.labels.df <- left_join(data.frame(id = idList, centroids.df), sch_cw, by=c("id"="sch_name_clean"))

appalachia.labels <- text.labels.df %>% filter(county_name %in% appalachia.sch)
appalachia.labels = appalachia.labels[-c(1:2),]
appalachia.labels$id2 <- gsub(" High", "", lettercase::str_title_case(tolower(appalachia.labels$sch_names)))
eastern.labels <- text.labels.df %>% filter(county_name %in% eastern.sch)
east.nonrichmond.labels <- eastern.labels %>% filter(id %in% c("Sussex Central High", "Powhatan High"))
east.nonrichmond.labels$id2 = east.nonrichmond.labels$id
richmond.labels <- eastern.labels %>% filter(!id %in% c("Open High", "Richmond Community High"))

eastern_data <- map_data %>% filter(!sch_name_clean %in% c("Open High", "Richmond Community High"))
richmond_data <- map_data %>% filter(county_name == "Richmond City") %>% filter(!sch_name_clean %in% c("Open High", "Richmond Community High"))
richmond_t.df <- virginia_t.df %>% filter(NAME %in% eastern) %>% filter(!id == 1700)


# APPALACHIA ------
data1 = map_data %>% filter(county_name %in% appalachia.sch)
geoZips = appalachia

# two year
viridis_map(variable = data1$totalProp_2YearCollegeEnrollment, 
            title = "Proportion of students enrolling in 2-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/APPALACHIAmap_prop_2year.pdf", 
            legend_position = c(0.3, 0.85),
            label_data = appalachia.labels)

# four year
viridis_map(variable = data1$totalProp_4YearCollegeEnrollment, 
            title = "Proportion of students enrolling in 4-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/APPALACHIAmap_prop_4year.pdf", 
            legend_position = c(0.3, 0.85),
            label_data = appalachia.labels)

# disadvantaged two year
viridis_map(variable = data1$disadvY_2_year_ps_prop, 
            title = "Proportion of disadvantaged students enrolling in 2-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/APPALACHIAmap_prop_disadv2year.pdf", 
            legend_position = c(0.35, 0.85),
            label_data = appalachia.labels)

# disadvantaged four year
viridis_map(variable = data1$disadvY_4_year_ps_prop, 
            title = "Proportion of disadvantaged students enrolling in 4-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/APPALACHIAmap_prop_disadv4year.pdf", 
            legend_position = c(0.35, 0.85),
            label_data = appalachia.labels)

# ROANOKE ZOOM ---------
data1 = map_data %>% filter(county_name %in% roanoke_county)
geoZips = virginia_t.df %>% filter(NAME == "Roanoke")
# two year
viridis_mapZOOM(variable = data1$totalProp_2YearCollegeEnrollment, 
            title = "Proportion of students \n enrolling in 2-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/ROANOKE-ZOOMmap_prop_2year.pdf", 
            legend_position = c(0.83, 0.1),
            label_data = appalachia.labels %>% filter(county_name %in% roanoke_county))

# four year
viridis_mapZOOM(variable = data1$totalProp_4YearCollegeEnrollment, 
            title = "Proportion of students \n enrolling in 4-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/ROANOKE-ZOOMmap_prop_4year.pdf", 
            legend_position = c(0.83, 0.1),
            label_data = appalachia.labels %>% filter(county_name %in% roanoke_county))

# two year disadvantaged
viridis_mapZOOM(variable = data1$disadvY_2_year_ps_prop, 
            title = "Proportion of disadvantaged students \n enrolling in 2-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/ROANOKE-ZOOMmap_prop_disadv2year.pdf", 
            legend_position = c(0.83, 0.1),
            label_data = appalachia.labels %>% filter(county_name %in% roanoke_county))

# four year disadvantaged
viridis_mapZOOM(variable = data1$disadvY_4_year_ps_prop, 
            title = "Proportion of disadvantaged students \n enrolling in 4-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/ROANOKE-ZOOMmap_prop_disadv4year.pdf", 
            legend_position = c(0.83, 0.1),
            label_data = appalachia.labels %>% filter(county_name %in% roanoke_county))

# RICHMOND/EASTERN ------
data1 = eastern_data %>% filter(county_name %in% eastern.sch)
geoZips = richmond_t.df %>% filter(NAME %in% eastern & lat < 1800000)

# EASTERN (all non-appalachia schools, excluding open high and richmond community high, not labeling richmond schools) -----
# two year
viridis_map(variable = data1$totalProp_2YearCollegeEnrollment, 
            title = "Proportion of students enrolling \n in 2-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/EASTERNmap_prop_2year.pdf", 
            legend_position = c(0.19, 0.14),
            label_data = east.nonrichmond.labels)

# four year
viridis_map(variable = data1$totalProp_4YearCollegeEnrollment, 
            title = "Proportion of students enrolling \n in 4-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/EASTERNmap_prop_4year.pdf", 
            legend_position = c(0.19, 0.14),
            label_data = east.nonrichmond.labels)

# disadvantaged two year
viridis_map(variable = data1$disadvY_2_year_ps_prop, 
            title = "Proportion of disadvantaged students \n enrolling in 2-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/EASTERNmap_prop_disadv2year.pdf", 
            legend_position = c(0.19, 0.14),
            label_data = east.nonrichmond.labels)

# disadvantaged four year
viridis_map(variable = data1$disadvY_4_year_ps_prop, 
            title = "Proportion of disadvantaged students \n enrolling in 4-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/EASTERNmap_prop_disadv4year.pdf", 
            legend_position = c(0.19, 0.14),
            label_data = east.nonrichmond.labels)

# FOCUS ON RICHMOND CITY ONLY (excluding open high and richmond community high) -------
data1 =  richmond_data %>% filter(county_name %in% eastern.sch)
geoZips = virginia_t.df %>% filter(NAME %in% richmond_city)
richmond.labels$id2 = richmond.labels$id
# two year
viridis_mapZOOM(variable = data1$totalProp_2YearCollegeEnrollment, 
            title = "Proportion of students \n enrolling in 2-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/RICHMOND-ZOOMmap_prop_2year.pdf", 
            legend_position = c(0.20, 0.14),
            label_data = richmond.labels %>% filter(county_name %in% richmond_city))

# four year
viridis_mapZOOM(variable = data1$totalProp_4YearCollegeEnrollment, 
            title = "Proportion of students \n enrolling in 4-year colleges", 
            file_path = "Code/Maddie/output/publication_maps/RICHMOND-ZOOMmap_prop_4year.pdf", 
            #legend_position = c(0.22, 0.14),
            legend_position = c(0.20, 0.14),
            label_data = richmond.labels %>% filter(county_name %in% richmond_city))

# disadvantaged two year
viridis_mapZOOM(variable = data1$disadvY_2_year_ps_prop, 
            title = "Proportion of disadvantaged \n students enrolling in 2-year \n colleges", 
            file_path = "Code/Maddie/output/publication_maps/RICHMOND-ZOOMmap_prop_disadv2year.pdf", 
            legend_position = c(0.20, 0.14),
            label_data = richmond.labels %>% filter(county_name %in% richmond_city))

# disadvantaged four year
viridis_mapZOOM(variable = data1$disadvY_4_year_ps_prop, 
            title = "Proportion of disadvantaged \n students enrolling in 4-year \n colleges", 
            file_path = "Code/Maddie/output/publication_maps/RICHMOND-ZOOMmap_prop_disadv4year.pdf", 
            legend_position = c(0.20, 0.14),
            label_data = richmond.labels %>% filter(county_name %in% richmond_city))

