### This script combines t1RawDataExclude variables across projects
###
### Ellyn Butler
### April 20, 2020


seslabel_df <- read.csv("/Users/butellyn/Documents/ExtraLong/data/organize/scanid_to_seslabel_10-16-2019.csv")
pnc_df <- read.csv("/Users/butellyn/Documents/ExtraLong/data/QA/n2416_t1QaData_20170516.csv")
grmpy_df <- read.csv("/Users/butellyn/Documents/ExtraLong/data/QA/n118_structQAFlags_20171103.csv")
reward_df <- read.csv("/Users/butellyn/Documents/ExtraLong/data/QA/n489_reward_QAFlags_Structural_final.csv")

##### Just identifiers and t1RawDataExclude #####
pnc_df <- pnc_df[,c("bblid", "scanid", "t1RawDataExclude")]
grmpy_df <- grmpy_df[,c("bblid", "scanid", "ManualRating")]

multi_full <- Reduce(
  function(x, y, ...) merge(x, y, all = TRUE, ...),
  flightsList
)
