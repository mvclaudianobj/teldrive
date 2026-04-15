package cmd

import (
	"github.com/spf13/cobra"
)

func New() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "marksdrive",
		Short: "Marks Drive",
		Run: func(cmd *cobra.Command, args []string) {
			cmd.Help()
		},
	}
	cmd.AddCommand(NewRun(), NewCheckCmd(), NewUpdateCmd(), NewVersion())
	return cmd
}
