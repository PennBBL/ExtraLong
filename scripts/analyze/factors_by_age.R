### This script plots age for each visit, colored by unique combinations
### of scanning parameters
###
### Ellyn Butler
### June 3, 2020

library('ggplot2')
library('ggpubr')
library('dplyr')

params_df <- read.csv('~/Documents/ExtraLong/data/acquisitionInfo/parameters.csv')
demo_df <- read.csv('~/Documents/ExtraLong/data/demographicsClinical/scanid_to_seslabel_demo_20200531.csv')

full_df <- merge(params_df[, 2:10], demo_df)

sortedBBLID <- full_df %>% group_by(bblid) %>% summarise(m=min(scanage_years)) %>% arrange(m)
sortedBBLID$row <- as.numeric(rownames(sortedBBLID))
newDataTable <- full_df %>% left_join(sortedBBLID%>%select(bblid,row),by="bblid")
sortedBBLID$bblid <- factor(sortedBBLID$bblid)
newDataTable$sex <- recode(newDataTable$sex, `2`="Female", `1`="Male")

sex_fig <- ggplot(data = newDataTable, aes(x=reorder(row,scanage_years,FUN = min),
    y=scanage_years,color=sex)) + theme_linedraw() +
  geom_point(size=.5,alpha=.5) + geom_line(alpha=.5) +
  scale_x_discrete(breaks = seq(1, length(sortedBBLID$bblid), 50)) +
  coord_flip(clip = "off") +
  scale_color_manual(values = c("blue","red"), labels=c("Male","Female"))+
  labs(y = "Age (years)", x = "Participant", color="") +
  theme(legend.position = c(.8,.2))

race_fig

diagnosis_fig

param_fig


pdf(file="~/Documents/ExtraLong/plots/age_by_important_factors.pdf")
ggarrange(sex_fig, race_fig, diagnosis_fig, param_fig, nrow=2, ncol=2,
          labels=c("A", "B", "C", "D"))
dev.off()
