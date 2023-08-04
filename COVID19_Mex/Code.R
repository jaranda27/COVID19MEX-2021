#Import libraries and dataset
library(tidyverse)
library(mxmaps)
library(readr)
library(readxl)
library(knitr)
library(scales)
library(gridExtra)
library(cowplot)
Entities <- read_xlsx("C:/Users/jorge/Desktop/R datasets/COVID-19_MEX/COVID19_Mex/201128 Catalogos.xlsx",
                      sheet="CATALOGO_ENTIDADES") 
open_data_mex <- read_csv("C:/Users/jorge/Desktop/R datasets/COVID-19_MEX/COVID19_Mex/COVID19MEXICO2021.csv")
open_data_mex <- open_data_mex %>% filter(CLASIFICACION_FINAL %in% c(1,2,3)) %>% 
  mutate(FECHA_ACTUALIZACION = ymd(FECHA_ACTUALIZACION)) %>% 
  inner_join(Entities, by=c("ENTIDAD_RES"="CLAVE_ENTIDAD")) #filter for positive cases only and add entities

# Distribution map 

open_data_mex_grouped <- open_data_mex %>% 
  group_by(ENTIDAD_FEDERATIVA) %>% 
  summarise(Total= n()) %>% 
  arrange(ENTIDAD_FEDERATIVA) 

data("df_mxstate_2020")  #import Mexico map

df_mxstate_2020 <- df_mxstate_2020 %>% arrange(state_name) # arrange state name alphabetically so they match the order in open_data_mex_grouped

df_mxstate_2020 <- df_mxstate_2020 %>% 
  mutate(value=round(open_data_mex_grouped$Total*100/df_mxstate_2020$pop,digits = 1)) 

# Plot map and distribution 

mx_map <- mxstate_choropleth(df_mxstate_2020,
                             num_colors = 1,
                             title = "COVID-19 Spread Across the Country in 2021",
                             legend= "Infection rate (%)") +
  labs(subtitle = 
         "Probability of getting infected by COVID-19 in 2021",
       caption = c("Source: Mexican General Direction of Epidemiology",
                   "Historic COVID-19 database (2021) ")) + 
  theme(title = element_text(size=17,face = "bold"),
        legend.title = element_text(size=12),
        legend.text = element_text(size=10),
        plot.subtitle = element_text(size=12),
        plot.caption = element_text(size=c(10,8),
                                    hjust = c(1,1),
                                    vjust= c(0.6,0.2)))

df_mxstate_2020 <- df_mxstate_2020 %>% arrange(desc(value))
Table <- kable(head(df_mxstate_2020[,c("state_name", "value")]),col.names=c("State","Infection rate"))
mx_map
Table


#Tracing covid19 in mex 2021
open_data_mex_month <- open_data_mex %>% 
  mutate(
    SEXO=ifelse(
      SEXO==1,
      "Female",
      "Male"),
    MES_INGRESO=month(FECHA_INGRESO,label=T,abbr=T))

data_month <- open_data_mex_month %>% 
  group_by(MES_INGRESO,FECHA_INGRESO,SEXO) %>% summarise(Total=n())

data_p2 <- open_data_mex_month %>% group_by(MES_INGRESO) %>%
  summarise(Total=n()) %>% mutate(cumsum=cumsum(Total))

data_p1 <- data_month %>% group_by(MES_INGRESO,SEXO) %>% 
  summarise(avg=IQR(Total))

#creat first plot

p1 <- ggplot(data_p1,aes(MES_INGRESO,avg,fill=SEXO)) + 
  geom_col(position="stack") + 
  scale_fill_manual(values=c("#D2DFF7","#2B3D5E")) + 
  scale_y_continuous(expand = expansion(mult=c(0,0.01)),
                     name=" Average total cases per day",
                     position = "left") + 
  scale_x_discrete(name="Month") + 
  labs(title="Confirmed cases during 2021",
       subtitle = "Average and Cumulative Confirmed COVID-19 Cases \nper Month in Mexico - 2021") + 
  theme_half_open(font_size = 14) +
  theme(legend.position = "bottom",
        legend.justification = "center",
        legend.title = element_blank(),
        plot.title = element_text(size=15))

#Create second plot 

p2 <- ggplot(data_p2,aes(MES_INGRESO,cumsum,group=1)) + 
  geom_point(col="#D93E32",size=3) + geom_line(col="#D93E32",
                                               size=1.3,
                                               alpha=0.3) +
  scale_y_continuous(expand = expansion(mult=c(0,0.01)),
                     name="Cumulative total cases",
                     position="right") + 
  theme_half_open(font_size=14) +
  theme(axis.title.x = element_blank(),
        axis.text.x = element_blank(),
        axis.text.y=element_text(color="#D93E32"),
        axis.ticks = element_blank(),
        axis.line = element_blank(),
        panel.grid.major.y = element_line(size=0.8,
                                          color= "#D93E32",
                                          linetype = "dashed"))
#aling and superimpose p1 and p2

aligned_plots <- align_plots(p1, p2, align="hv", axis="tblr")
plots_p12 <- ggdraw(aligned_plots[[1]]) + draw_plot(aligned_plots[[2]])
ggsave("p12.png",height = 5, width = 7)

#Data manipulation for third plot

deaths_sex <- open_data_mex_month %>%   
  filter(!is.na(FECHA_DEF)) %>% 
  group_by(SEXO) %>% 
  summarize(Total=n()) %>% 
  mutate(fraction=Total/sum(Total),
         ymax=cumsum(fraction),
         ymin=c(0,head(ymax,n=-1)),
         label_pos=(ymax+ymin)/2,
         label=paste0(SEXO, "\nDeaths: ", Total))

labels_2 <- data.frame(SEXO=deaths_sex$SEXO,Total=deaths_sex$Total,x=c(1,1),y=c(20000,6000))

#Third plot

deaths_plot <- ggplot(deaths_sex,aes(ymax=ymax,ymin=ymin,xmax=4,xmin=3,fill=SEXO)) + 
  geom_rect() + 
  geom_text(aes(x=1.1,y=label_pos,label=label,color=SEXO),
            size=4.2)+
  coord_polar(theta="y")+
  scale_fill_manual(values=c("#D2DFF7","#2B3D5E"))+
  scale_color_manual(values=c("#D2DFF7","#2B3D5E"))+
  xlim(c(-1,4)) +
  theme_half_open(font_size=15) + 
  labs(title="Lethality in 2021",
       subtitle="Proportions of death patients by sex") + 
  theme(legend.position = "none",
        plot.title = element_text(size=15),
        axis.text = element_blank(),
        axis.title = element_blank(),
        axis.line = element_blank(),
        axis.ticks = element_blank()
  )
plots_p12
deaths_plot

#prop.test to compare proportions
deaths <- deaths_sex %>% pull(Total)
test <- prop.test(deaths,c(rep(sum(deaths),2)))


#patients distribution (ambulatory, hospitalized)

data_by_age <- open_data_mex %>% filter(!is.na(EDAD)) %>%
  mutate(EDAD=case_when(
    .$EDAD<10 ~ "0-9",
    .$EDAD>=10 & .$EDAD<20 ~ "10-19",
    .$EDAD>=20 & .$EDAD<30 ~ "20-29",
    .$EDAD>=30 & .$EDAD<40 ~ "30-39",
    .$EDAD>=40 & .$EDAD<50 ~ "40-49",
    .$EDAD>=50 & .$EDAD<60 ~ "50-59",
    .$EDAD>=60 & .$EDAD<70 ~ "60-69",
    .$EDAD>=70 & .$EDAD<80 ~ "70-79",
    .$EDAD>=80 & .$EDAD<90 ~ "80-89",
    .$EDAD>=90 ~ ">90"))

data_by_patients <- data_by_age %>% mutate(
  TIPO_PACIENTE=ifelse(TIPO_PACIENTE==2,
                       "Hospitalized",
                       "Ambulatory"),
  EDAD=fct_relevel(EDAD, "0-9", "10-19",
                   "20-29","30-39",
                   "40-49","50-59",
                   "60-69","70-79",
                   "80-89",">90")) %>% 
  group_by(EDAD,TIPO_PACIENTE) %>% 
  summarise(Total=n()) %>% 
  mutate(Prop=Total/sum(Total))

labels <- data_by_patients %>% filter(TIPO_PACIENTE == "Hospitalized") %>%
  mutate(label=paste0(round(Prop*100,digits=1),'%'))

plot_by_patients <- ggplot(data_by_patients,aes(EDAD,Total,fill=TIPO_PACIENTE)) + 
  geom_col(position = "fill",
           width = 0.7) + 
  geom_text(data=labels,aes(EDAD,Prop,label=label),
            hjust=-0.2,
            vjust=-0.6,
            nudge_x = -0.3,
            fontface='bold',
            color='grey30') +
  scale_fill_manual(values=c("#D2DFF7","#2B3D5E")) +
  scale_y_continuous(expand=expansion(mult=c(0,0.01))) +
  labs(title="Insights into COVID-19 patient distribution",
       subtitle="A comparative analysis of ambulatory and hospitalized cases \nacross age groups",
       xlab="Age group in years") +
  coord_flip() + 
  theme_half_open(font_size = 15) +
  theme(axis.title= element_blank(),
        axis.text.x= element_blank(),
        axis.line.x= element_blank(),
        axis.ticks= element_blank(),
        axis.line.y= element_line(color='grey30',
                                  linewidth = 0.5),
        axis.text.y =element_text(face="bold",
                                  color="black"),
        legend.position = "bottom",
        legend.title = element_blank(),
        legend.justification = "center"
  )
plot_by_patients

#age and pre-existing diseases 
cases_by_age <- data_by_age %>% group_by(EDAD)%>%
  summarise(Total = n())
letality_rate <- data_by_age %>% filter(!is.na(FECHA_DEF)) %>%
  group_by(EDAD) %>% summarise(Total= n()) %>% 
  inner_join(cases_by_age, by="EDAD", suffix=c("_death","_cases")) %>% 
  mutate(let_rate=round(Total_death*100/Total_cases,digits = 1),
         label=paste0(let_rate,"%"))

letality_plot <- letality_rate %>%
  mutate(EDAD=fct_relevel(EDAD, "0-9", "10-19",
                          "20-29","30-39",
                          "40-49","50-59",
                          "60-69","70-79",
                          "80-89",">90"))%>%
  ggplot(aes(EDAD,let_rate)) + 
  geom_col(position = "dodge",fill="#2B3D5E",width=0.7) + 
  geom_text(aes(EDAD,let_rate,label=label),
            hjust=-0.2,
            vjust=-0.5,
            nudge_x = -0.3,
            fontface='bold',
            color='grey30') + 
  coord_flip() + 
  theme_half_open(font_size=15) + 
  scale_y_continuous(expand = expansion(mult=c(0,0.1))) + 
  labs(title="Case fatality rate by age groups",
       subtitle="Chances of dying increase drastically after 70 years old",
       xlab="Age group in years")+
  theme(axis.title= element_blank(),
        axis.text.x= element_blank(),
        axis.line.x= element_blank(),
        axis.ticks= element_blank(),
        axis.line.y= element_line(color='grey30',
                                  linewidth = 0.5),
        axis.text.y =element_text(face="bold",
                                  color="black")
  )
letality_plot

#Comorbility 

comorb <- data_by_age %>%
  mutate(across(.cols=c(DIABETES,EPOC,ASMA,HIPERTENSION,INMUSUPR,OTRA_COM),
                .fns= ~ifelse(.x %in% c(98,2),0,1)))
sel_fun <- function (x) {
  dplyr::select(.data=x,EDAD,DIABETES,EPOC,ASMA,INMUSUPR,HIPERTENSION,OTRA_COM) %>%
    dplyr::mutate(comorbilidades = rowSums(across(where(is.numeric)))) %>%
    dplyr::mutate(comorbilidades = case_when(
      .$comorbilidades == 0 ~ "None",
      .$comorbilidades == 1 ~ "One",
      .$comorbilidades ==2 ~ "Two",
      .$comorbilidades >=3 ~ "Three or more")) %>%
    dplyr::group_by(EDAD,comorbilidades) %>% 
    dplyr::summarise(Total=n())
}

comorb_death <- comorb %>% filter(!is.na(FECHA_DEF)) %>% 
  sel_fun()

comorb_plot <- comorb %>% 
  sel_fun() %>% full_join(comorb_death,by=c("EDAD", "comorbilidades"),
                          suffix=c("_Cases","_Death")) %>% 
  mutate(Total_Death=replace_na(Total_Death,0),
         let_rate = round(Total_Death*100/Total_Cases),
         label= paste0(let_rate, "%"),
         EDAD=fct_relevel(EDAD, "0-9", "10-19",
                          "20-29","30-39",
                          "40-49","50-59",
                          "60-69","70-79",
                          "80-89",">90"),
         comorbilidades=fct_relevel(comorbilidades,
                                    "None",
                                    "One","Two",
                                    "Three or more")) %>%
  ggplot(aes(comorbilidades,let_rate,fill=comorbilidades)) +
  geom_col(postition="dodge",width = 0.7) + 
  geom_text(aes(comorbilidades,let_rate,label=label),
            size= 3, 
            hjust=-0.2,
            vjust=-0.3,
            nudge_x = -0.3,
            fontface='bold',
            color='grey30') + 
  theme_half_open(font_size = 15) +
  coord_flip()+ 
  labs(title="Case fatality rate and comorbilities",
       subtitle= paste0("Chances of die by COVID-19 according to your age",
                        "\nand the number of comorbilities")) + 
  scale_fill_manual(values=c("#D2DFF7","#6690DE","#4F6FAB","#2B3D5E")) + 
  scale_y_continuous(expand = expansion(mult=c(0,0.3))) +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank(),
        strip.background = element_blank(),
        strip.text = element_text(face = "bold"),
        axis.line = element_blank(),
        axis.title = element_blank(),
        axis.ticks = element_blank(),
        axis.text = element_blank(),
        legend.position = "bottom",
        legend.title = element_blank(),
        legend.justification = "center",
        plot.subtitle = element_text(size=12))+
  facet_wrap(EDAD~.) +  geom_hline(yintercept=0,color="black")

comorb_plot
ggsave("comorbilities.png",width= 7, height = 5, units = "in")

deaths <- comorb_death %>% group_by(comorbilidades) %>% 
  summarise(Total=sum(Total)) %>% arrange(desc(Total)) %>%
  pull(Total)

comord_names <- c("None","One","Two","Three or more")

survive <- comorb %>% filter(is.na(FECHA_DEF)) %>%
  sel_fun() %>% group_by(comorbilidades) %>%
  summarise(Total=sum(Total)) %>% arrange(desc(Total)) %>% 
  pull(Total)


dependency_matrix <- matrix(c(survive,deaths),byrow = T,
                            nrow = 2,
                            dimnames = list(c("Survived","Death"),
                                            c(comord_names)))
names(dimnames(dependency_matrix)) <- list(c("Type of patient"),
                                           c("Comorbilities"))

#Independency test using chi-square test
dependency_test <- chisq.test(dependency_matrix)

