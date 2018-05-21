*FINAL PROJECT;
filename shortcut "/folders/myfolders/Data/224 Final Data/*.txt";
*Generate formats for converting letter grades into numbers;

proc format ;
	invalue lettertnum "A"=4.0 "A-"=3.7 "B+"=3.4 "B"=3.0 "B-"=2.7 "C+"=2.4 "C"=2.0 
		"C-"=1.7 "D+"=1.4 "D"=1.0 "D-"=0.7 other=0.0;
run;

*Generate formats for determining class standing;

proc format ;
	value class_standing 0-<30="Freshman" 30-<60="Sophomore" 60-<90="Junior" 
		other="Senior";
run;

*Simple macro for counting number of A's B's C's etc;

%macro lettergrades(x);
	if substr(Grade, 1, 1)="&x" then &x + 1;
%mend;

*Read in the data;

data final;
	infile shortcut dlm="@";
	length ID $ 5 Course $ 10;
	input ID $ Date $ Course $ Credit Grade $;
	Year=substr(Date, 2, 2);
	Semester=substr(Date, 1, 1);
	GPAgrade=input(Grade, lettertnum.);

	/*Count number of A's B's C's etc */
	A=0;
	B=0;
	C=0;
	D=0;
	E=0;
	W=0;
	%lettergrades(A);
	%lettergrades(B);
	%lettergrades(C);
	%lettergrades(D);
	%lettergrades(E);
	%lettergrades(W);
run;

proc sort data=final;
	by ID Course GPAgrade;
run;

*Create a variable that counts up if course is repeated, to be summed later for overall repeat courses;
data final;
	set final;
	by ID Course;
	repeat=0;
	count + 1;

	if last.Course then
		do;
			repeat=count;
			count=0;
		end;

	if repeat=0 then
		repeat=0;
	else
		repeat=repeat - 1;
run;

*Remove all but the highest graded class, if repeated;
*By sorting and choosing the last of the duplicates;
data final;
	set final;
	by ID Course;

	if last.Course;
run;

data final;
	set final;

	/*Determine Earned and Graded Credit Amounts */
	if substr(Grade, 1, 1)="W" then
		Credit=0;
	EarnedCredit=Credit;
	GradedCredit=Credit;

	if GPAgrade=0.0 then
		do;
			EarnedCredit=0;
			GradedCredit=0;
		end;

	if substr(Grade, 1, 1)="P" then
		do;
			EarnedCredit=Credit;
			Credit=0;
			GradedCredit=0;
		end;
run;

*Subset the data set for only Math and Stat classes for report 2;
data mathandstat;
	set final;
	if substr(Course, 1, 4)="MATH" or substr(Course, 1, 4)="STAT";
run;

*Make the calculations for the semester values;
proc sql ;
	create table semestercalculations as select ID, Year, Semester, Credit, 
		sum(Credit) as SemCredit, GPAgrade, sum(Credit * GPAgrade) as weighted, 
		calculated weighted/calculated SemCredit as SemesterGPA format=4.2, 
		sum(EarnedCredit) as SemEarnedCredit, sum(GradedCredit) as SemGradedCredit 
		from final group by ID, Year, Semester;
	run;

*Calculate overall and Math and Stat values using a macro;
%macro calculate(name, file, EarnedCredit, GradedCredit, GPA, A, B, C, D, E, 
	W, RpCourses);
proc sql ;
	create table &name as select ID, sum(EarnedCredit) as &EarnedCredit, 
		sum(GradedCredit) as &GradedCredit, sum(Credit) as overallCredit, sum(Credit 
		* GPAgrade) as overallWeighted, calculated overallWeighted/calculated 
		overallCredit as &GPA format=4.2, sum(A) as &A, sum(B) as &B, sum(C) as &C, 
		sum(D) as &D, sum(E) as &E, sum(W) as &W, sum(repeat) as &RpCourses
		from &file
		group by ID;
	run;
%mend;

%calculate(overallcalculations, final, overallEarnedCredit, 
	overallGradedCredit, overallGPA, A, B, C, D, E, W, RepeatCourses);
%calculate(mathstatcalcs, mathandstat, MSEarnedCredit, MSGradedCredit, MSGPA, 
	MSA, MSB, MSC, MSD, MSE, MSW, MSRpCourses);

*Select all important variables and sort;
proc sql ;
	create table weightedGPA1 as select ID, Year, Semester, weighted, SemCredit, 
		SemesterGPA, SemEarnedCredit, SemGradedCredit from semestercalculations 
		order by ID, Year, Semester;
	run;
*Merge semester and overall calculations from above to begin Report 1;
data report;
	merge weightedGPA1 overallcalculations;
	by ID;
run;
*Remove the duplicate values, lots of repeating data;
proc sort data=report OUT=reporta Nodupkey;
	by ID Year Semester;
run;

*Add in Cumulative GPA and class standing;
data cumulative (keep=ID Year Semester SemesterGPA CumGPA SemEarnedCredit 
		SemGradedCredit classStanding overallGPA overallEarnedCredit 
		overallGradedCredit A B C D E W RepeatCourses);
	set reporta;
	by ID;

	if first.ID then
		do;
			CumGPA=0;
			CumWeight=0;
			CumCredit=0;
			CumECredit=0;
		end;
	CumWeight + weighted;
	CumCredit + SemCredit;
	CumGPA=CumWeight/CumCredit;
	CumECredit + SemEarnedCredit;
	format CumGPA 4.2;
	classStanding=CumECredit;
	format classStanding class_standing.;
run;

*Merge data from overall calculations and Math + Stat calculations for report 2;
data report2_1 (keep=ID overallEarnedCredit overallGradedCredit overallGPA A B 
		C D E W RepeatCourses MSEarnedCredit MSGradedCredit MSGPA MSA MSB MSC MSD MSE 
		MSW MSRpCourses);
	merge overallcalculations mathstatcalcs;
	by ID;
run;
*Create new (Prettier) names for the variables and ods to html;
options validvarname=any orientation=landscape linesize=256;
ods html file="/folders/myfolders/Data/reports.html";

*Rename and format Report 1;
data Report1;
	set cumulative;
	rename ID='Student ID'n Year=Year Semester=Semester SemesterGPA=GPA 
		CumGPA='Cumulative GPA'n SemEarnedCredit='Earned Credit'n 
		SemGradedCredit='Graded Credit'n classStanding='Class Standing'n 
		overallGPA='Overall GPA'n overallEarnedCredit="Overall Earned Credit"n 
		overallGradedCredit='Overall Graded Credit'n A='# of As'n B='# of Bs'n 
		C='# of Cs'n D='# of Ds'n E='# of Es'n W='# of Ws'n 
		RepeatCourses='# of Repeated Courses'n;
run;

*Rename and format Report 2;
data Report2;
	set report2_1;
	rename ID='Student ID'n overallGPA='Overall GPA'n 
		overallEarnedCredit="Overall Earned Credit"n 
		overallGradedCredit='Overall Graded Credit'n A='# of As'n B='# of Bs'n 
		C='# of Cs'n D='# of Ds'n E='# of Es'n W='# of Ws'n 
		RepeatCourses='# of Repeated Courses'n MSGPA='Math/Stat GPA'n 
		MSEarnedCredit="Math/Stat Earned Credit"n 
		MSGradedCredit='Math/Stat Graded Credit'n MSA='# of Math/Stat As'n 
		MSB='# of Math/Stat Bs'n MSC='# of Math/Stat Cs'n MSD='# of Math/Stat Ds'n 
		MSE='# of Math/Stat Es'n MSW='# of Math/Stat Ws'n 
		MSRpCourses='# of Math/Stat Repeated Courses'n;
run;

*Create Report 3;
proc sort data=report2_1 out=Report3;
	by descending overallGPA;
	where overallEarnedCredit > 60 and overallEarnedCredit < 130;
run;

data Report3 (keep='Student ID'n 'Overall GPA'n);
	set Report3 nobs=nobs;
	counter + 1;
	top = 0.1*nobs;
	if counter > top then stop;
	rename ID='Student ID'n overallGPA='Overall GPA'n;
run;



*Create Report 4;
proc sort data=report2_1 out=Report4;
	by descending overallGPA;
	where MSEarnedCredit > 20;
run;

data Report4 (keep='Student ID'n 'Overall GPA'n);
	set Report4 nobs=nobs;
	counter + 1;
	top = 0.1*nobs;
	if counter > top then stop;
	rename ID='Student ID'n overallGPA='Overall GPA'n;
run;

title 'Report 1';

proc report data=Report1;
run;

title 'Report 2';

proc report data=Report2;
run;

title 'Report 3';

proc report data=Report3; /*There are 125 observations, 10% is about 13*/
run;

title 'Report 4';

proc report data=Report4; /*There are 152 observations, 10% is about 15*/
run;

ods html close;